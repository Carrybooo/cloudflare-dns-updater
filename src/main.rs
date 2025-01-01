use clap::Parser;
use env_logger;
use log::{debug, error, info, warn, LevelFilter};
use public_ip;
use reqwest;
use reqwest::Client;
use serde::Deserialize;
use serde_json::Value;
use std::{
    env, fs,
    net::{Ipv4Addr, Ipv6Addr},
    path::PathBuf,
    str::FromStr,
    thread, time,
};

#[derive(Parser)]
struct Args {
    #[arg(short, long, default_value_t = false)]
    debug: bool,
    #[arg(long, default_value = "/etc/cloudflare-dns-updater/config.toml")]
    configpath: PathBuf,
}

#[derive(Deserialize)]
struct Config {
    check_interval: Option<u64>,
    setups: Vec<DnsSetup>,
}

#[derive(Deserialize, Debug)]
struct DnsSetup {
    zone_id: String,
    api_token: String,
    ipv4_record_name: Option<String>,
    ipv6_record_name: Option<String>,
    domain: String,

    #[serde(skip)] // Prevents these fields from being serialized/deserialized
    ipv4_save: Option<Ipv4Addr>,
    #[serde(skip)]
    ipv6_save: Option<Ipv6Addr>,
}

#[tokio::main]
async fn main() {
    // Init Args and logger

    let args = Args::parse();

    // set debug to true if either DEBUG env var is true (or 1) or --debug is set
    let debug: bool = if let Ok(env_debug) = env::var("DEBUG") {
        match env_debug.to_lowercase().as_str() {
            "true" | "1" => true,
            "false" | "0" => false,
            _ => {
                warn!(
                    "Invalid value for DEBUG environment variable: {}. Defaulting to false.",
                    env_debug
                );
                false
            }
        }
    } else {
        args.debug
    };

    let level_filter: LevelFilter = match debug {
        true => LevelFilter::Debug,
        false => LevelFilter::Info,
    };

    env_logger::Builder::new().filter_level(level_filter).init();

    let mut config: Config;

    // Load the config file
    match fs::read_to_string(&args.configpath) {
        Ok(config_content) => {
            // Load configuration from file
            config = toml::from_str(config_content.as_str()).expect(
                format!("Failed to parse config file {}", args.configpath.display()).as_str(),
            );
            info!("Config loaded from: {}", args.configpath.display());
        }
        Err(err) => {
            error!(
                "Failed to load configuration file at {}: {}",
                args.configpath.display(),
                err
            );
            std::process::exit(1);
        }
    }

    loop {
        // Retrieve IPs using `public_ip` crate
        let ipv4 = public_ip::addr_v4().await;
        let ipv6 = public_ip::addr_v6().await;

        // Ensure IPs are retrieved successfully

        if ipv4 == None {
            warn!("Failed to retrieve IPv4");
        };
        if ipv6 == None {
            warn!("Failed to retrieve IPv6");
        }

        info!("ipv4: '{:?}', ipv6: '{:?}'", ipv4, ipv6);

        for setup in &mut config.setups {
            if setup.ipv4_save == None {
                setup.ipv4_save = Some(Ipv4Addr::new(0, 0, 0, 0))
            };
            if setup.ipv6_save == None {
                setup.ipv6_save = Some(Ipv6Addr::new(0, 0, 0, 0, 0, 0, 0, 0))
            };

            // Update DNS records if changed
            if setup.ipv4_record_name != None {
                if let Some(ip) = ipv4 {
                    if ip != setup.ipv4_save.unwrap() {
                        if update_dns(
                            setup,
                            ip.to_string(),
                            "A",
                            setup.ipv4_record_name.clone().unwrap(),
                        )
                        .await
                        {
                            setup.ipv4_save = ipv4.clone();
                        }
                    }
                }
            }
            if setup.ipv6_record_name != None {
                if let Some(ip) = ipv6 {
                    if ip != setup.ipv6_save.unwrap() {
                        if update_dns(
                            setup,
                            ip.to_string(),
                            "AAAA",
                            setup.ipv6_record_name.clone().unwrap(),
                        )
                        .await
                        {
                            setup.ipv6_save = ipv6.clone();
                        }
                    }
                }
            }
        }

        let interval = config.check_interval.unwrap_or(10);
        thread::sleep(time::Duration::from_secs(interval));
    }
}

async fn update_dns(
    setup: &DnsSetup,
    content: String,
    record_type: &str,
    record_name: String,
) -> bool {
    info!(
        "Updating DNS record for domain '{}', record : '{}', IP: '{}'",
        setup.domain, record_name, content
    );

    let client = Client::new();

    let full_record_name = record_name.clone().to_lowercase() + "." + setup.domain.as_str();
    debug!("full_record_name = {}", full_record_name);

    // Step 1: List DNS records
    let get_records = client
        .get(format!(
            "https://api.cloudflare.com/client/v4/zones/{}/dns_records?type={}&name={}",
            setup.zone_id, record_type, full_record_name
        ))
        .header("Authorization", format!("Bearer {}", setup.api_token))
        .header("Content-Type", "application/json")
        .send()
        .await
        .expect("Failed to list DNS records after retries");

    let get_records_text = get_records.text().await.unwrap();
    debug!("Records text : {:?}", get_records_text);

    let get_records_json: Value =
        serde_json::from_str(&get_records_text).expect("Failed to parse DNS records response");

    if !get_records_json["success"].as_bool().unwrap_or(false) {
        error!(
            "Failed to fetch DNS record: {:?}",
            get_records_json["errors"]
        );
        return false;
    }

    let fallback: Vec<serde_json::Value> = vec![];
    let records = get_records_json["result"].as_array().unwrap_or(&fallback);

    debug!("Records list : {:?}", records);

    let record_id = records
        .iter()
        .find(|record| record["name"] == full_record_name)
        .and_then(|record| record["id"].as_str());

    debug!("Record id: {:?}", record_id);

    // Step 2: Update or create DNS record
    let method = if record_id.is_some() { "PUT" } else { "POST" };
    let url = if let Some(id) = record_id {
        format!(
            "https://api.cloudflare.com/client/v4/zones/{}/dns_records/{}",
            setup.zone_id, id
        )
    } else {
        format!(
            "https://api.cloudflare.com/client/v4/zones/{}/dns_records",
            setup.zone_id
        )
    };

    let update_response = client
        .request(reqwest::Method::from_str(method).unwrap(), &url)
        .header("Authorization", format!("Bearer {}", setup.api_token))
        .header("Content-Type", "application/json")
        .body(format!(
            r#"{{"type":"{}","name":"{}","content":"{}","ttl":1,"proxied":false}}"#,
            record_type, full_record_name, content
        ))
        .send()
        .await
        .expect("Failed to send DNS update after retries");

    let update_response_text = update_response.text().await.unwrap();

    debug!("Update response text : {:?}", update_response_text);

    let update_response_json: Value =
        serde_json::from_str(&update_response_text).expect("Failed to parse DNS update response");

    if !update_response_json["success"].as_bool().unwrap_or(false) {
        error!(
            "Failed to update DNS record: {:?}",
            update_response_json["errors"]
        );
        false
    } else {
        info!(
            "DNS record updated successfully for '{}' with IP '{}'",
            full_record_name, content
        );
        true
    }
}
