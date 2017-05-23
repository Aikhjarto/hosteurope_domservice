# hosteurope_domservice
Tools for managing the domains with kis.hosteurope.de

These scripts can require the following variable exported:
Your registered domain, your customer number and your password.
```
export HE_USERNAME="myusername"
export HE_PASSWORD="mypassword"
```

'hosteurope_domservice.sh' provides an interface to add, update, and delete DNS entries.

'hosteurope_update_DNS_A.sh' is intended to update a A-entry if your ISP works with dynamic IP addresses.

'hosteurope_dehydrated_hook.sh' is a hook script for dehydrated.sh which uses 'hosteurope_domservice.sh' to set the TXT entries.


