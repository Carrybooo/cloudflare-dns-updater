This is a minimalist DNS auto-updater for your A and AAAA records.
It's usefull when your ISP doesn't provide you a static IP.

It needs a config file `config.toml` (see the example `config.toml.example`)

It works as follows:
1. Retrieve public IPs of the machine (IPv4 and IPv6).
For each DNS setup in the config.toml :

2. Check if the cached IP is different from the one retrieved. If yes :
    - List existing DNS records to check if the record already exist
    - Update/add the DNS record
    - Cache the IP

3. Loop