# Cloudflare DNS Updater

## Overview
This tool is a lightweight Rust-based application designed to automatically update DNS records on Cloudflare based on the public IP addresses of your servers. It supports both IPv4 and IPv6 and ensures DNS records are kept up-to-date whenever public IPs change.

## Features
- Detects public IPv4 and IPv6 addresses.
- Updates DNS records on Cloudflare for specified domains and record types (A or AAAA).
- Uses Cloudflare's API for secure DNS management.
- Configuration via a TOML file.
- Adjustable check interval for periodic updates.

## Requirements
- [Rust toolchain and cargo](https://rustup.rs/) (for building the application).
- A Cloudflare account and API tokens with permission to manage DNS.
- A configuration file (`config.toml`) specifying the domains and credentials.

---

## Installation

### From Source
1. Clone this repository:
   ```bash
   git clone <repository_url>
   cd <repository_name>
   ```

2. Build the project:
   ```bash
   cargo build --release
   ```

3. Copy the built binary to your desired location:
   ```bash
   cp target/release/cloudflare-dns-updater /usr/local/bin/
   ```

4. Ensure the configuration file exists at `/etc/cloudflare-dns-updater/config.toml` or provide a custom path using the `--configpath` option.

### Using Nix
You can install the application as a Nix package or integrate it into your NixOS configuration.

#### Install with Nix
1. Clone this repository with flakes enabled:
   ```bash
   nix profile install github:Carrybooo/cloudflare-dns-updater
   ```

2. Run the application:
   ```bash
   cloudflare-dns-updater --configpath /path/to/config.toml
   ```

#### NixOS Integration
Add the flake as an input to your NixOS configuration:

```nix
{
  inputs.cloudflare-dns-updater.url = "github:Carrybooo/cloudflare-dns-updater";

  outputs = { self, nixpkgs, cloudflare-dns-updater }: {
    nixosConfigurations.myServer = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        cloudflare-dns-updater.nixosModules.cloudflare-dns-updater
      ];
    };
  };
}
```

Then, configure the service in your `configuration.nix`:

```nix
{
  services.cloudflare-dns-updater = {
    enable = true;
    config = ''
      # Interval in seconds for checking updates
      check_interval = 10

      [[setups]]
      domain = "example.com"
      ipv4_record_name = "home"
      ipv6_record_name = "home-v6"
      zone_id = "your_zone_id"
      api_token = "your_api_token"
    '';
  };
}
```

---

## Configuration
The application requires a `config.toml` file. Below is an example configuration:
```toml
# Interval in seconds for checking updates (optional, defaults to 10)
check_interval = 10

[[setups]]
domain = "example.com"
ipv4_record_name = ""  # Update the root domain "A" record
ipv6_record_name = "subdomain"  # Update subdomain.example.com "AAAA" record
zone_id = "your_zone_id"
api_token = "your_api_token"

[[setups]]
domain = "another-example.com"
ipv4_record_name = "subdomain2"  # Update subdomain2.another-example.com
ipv6_record_name = "@"  # "@" also works to update the root domain
zone_id = "another_zone_id"
api_token = "another_api_token"
```

### Configuration Fields
- **`check_interval`**: (Optional) Time interval (in seconds) between checks. Defaults to 10 seconds.
- **`setups`**: Array of DNS setups. Each setup includes:
  - `domain`: The domain to update (e.g., `example.com`).
  - `ipv4_record_name`: (Optional) Subdomain name for the IPv4 record (e.g., `home`). Use `""` or `"@"` to update the root domain. If omitted, no IPv4 record will be updated.
  - `ipv6_record_name`: (Optional) Subdomain name for the IPv6 record (e.g., `home-v6`). Use `""` or `"@"` to update the root domain. If omitted, no IPv6 record will be updated.
  - `zone_id`: Cloudflare Zone ID for the domain.
  - `api_token`: Cloudflare API token with DNS edit permissions.

---

## Usage
Run the application with the following command:

```bash
cloudflare-dns-updater [OPTIONS]
```

### Options
- `--debug`: Enable debug-level logging.
- `--configpath <PATH>`: Specify the path to the configuration file. Defaults to `/etc/cloudflare-dns-updater/config.toml`.

### Example
Run with a custom configuration file:

```bash
cloudflare-dns-updater --configpath /path/to/config.toml
```

---

## Logs
Logs are written to the console and include timestamps. Use the `--debug` flag or set the `DEBUG` environment variable to `1` or `true` to enable detailed debug logs:

```bash
DEBUG=true cloudflare-dns-updater
```

---

## How It Works
1. **Load Configuration**: The application reads the `config.toml` file to configure setups.
2. **Fetch Public IPs**: It retrieves the server's current public IPv4 and IPv6 addresses using the `public_ip` crate.
3. **Check and Update DNS Records**:
   - Compares the current public IPs with the last known IPs stored in memory.
   - If an IP change is detected, it updates the corresponding DNS record on Cloudflare.
4. **Repeat**: The application sleeps for the configured interval and repeats the process.

---

## Security
- **Secrets Management**: Use API tokens with restricted DNS edit permissions for better security.