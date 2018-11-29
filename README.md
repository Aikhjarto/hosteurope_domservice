# HINT: As of 2018, hoseurope change the authentication method for kis.hosteurope.de so this scripts do not work since then.

# hosteurope_domservice
Tools for managing the domains with http://kis.hosteurope.de

These scripts require your username and password for kis.hosteurope.de to be exported like
```
export HE_USERNAME="myusername"
export HE_PASSWORD="mypassword"
```

* `hosteurope_domservice.sh` provides an interface to add, update, and delete DNS entries.

* `hosteurope_update_DNS_A.sh` is intended to update a A-entry if your ISP works with dynamic IP addresses.

* `hosteurope_dehydrated_hook.sh` is a hook script for dehydrated.sh which uses `hosteurope_domservice.sh` to set the TXT entries.

