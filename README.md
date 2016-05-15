# hosteurope_domservice
Tools for managing the domains with kis.hosteurope.de

These scripts can require the following variable exported:
Your registered domain, your customer number and your password.
```
export HE_DOMAIN="my.domain.org"
export HE_CNUMBER="12345"
export HE_PASSWORD="mypassword"
```

'hosteurope_domservice.sh' provides an interface to add, update, and delete DNS entries.

'hosteurope_update_DNS_A.sh' is intended to update a A-entry if your ISP works with dynamic IP addresses.

'hosteurope_letsencrypt_hook.sh' is a hook script for letsencrypt.sh which uses 'hosteurope_domservice.sh' to set the TXT entries.


