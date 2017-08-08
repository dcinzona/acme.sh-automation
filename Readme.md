# Automation wrapper for [Acme.sh](https://github.com/Neilpang/acme.sh)

This is a shell wrapper for the [Acme.sh](https://github.com/Neilpang/acme.sh) script, that automates the process of validation via CloudFlare as well as generating a PKCS12 pfx cert and JKS bundle.

This wrapper supports specifying domain alternates as a CSV list, instead of having to have a separate flag for each domain, where the first one is defined as the primary. Instead, you define the primary domain (this will become the name of the certificate and folder store) and any alternates.

This also outputs the cert bundles to the directory where the script is run, which will help when automating the process via Jenkins or some other CI tool that supports bash shell scripting.

## Example execution

```shell
./gencerts.sh -p tandeciarz.com \
--cfkey my-cloudflare-api-key \
--cfemail me@example.com \
-d test2.tandeciarz.com,sub1.tandeciarz.com,sub2.tandeciarz.com \
-d otherdomain.com,sub.otherdomain.com
```

## Todo

- [ ] Test using multiple root domains and CloudFlare (may need to split up root domain execution calls / api keys)
- [ ] Allow using JSON file for paramaters
- [ ] Migrate to NodeJS?