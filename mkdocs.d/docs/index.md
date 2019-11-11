<!--BEGINTOC-->


<!-- [TOC] -->


<!--ENDTOC-->

## Summary

Client Side Authentification is the counterpart to Server Authentication in HTTPS, together making Two-way Authentication.  Using a private CA (Certificate Authority) to issue both Server and Client certificates is a sensible approach.  This document provides a step-by-step example where *lighttpd v1.4.45* is server, and Firebox Browser v65.0 is client.

<!-- ----------------------------------------------- -->

## <a name="fullexample"></a> Example setup with *lighttpd* and *Firefox*

### Specs for the certs

We describe the certs and what fields they must contain.
A table is used to show what role they play in authentication. 


We need one private root and two leaf certificates with the following specifications:

##### Table 1: Cert specifications {: id=table-cert-specs }

Property          | CA cert        |  Server cert                                       |  Client cert
------------------|----------------|-------------                                       |----
type              | CA             | Leaf                                               |  Leaf
CN (common name)  | Root1          | Server1                                            | Client1
subjectAltName    | N/A            | DNS:pihole.home.lan,DNS:pihole,IP:192.168.1.20 | N/A
Key filename      | Root1.key      | Server1.key                                        | Client1.key
Cert filname      | Root1.crt      | Server1.crt                                        | Client1.crt 
Key+Cert filename | N/A            | Server1.key-crt.pem                                | Client1.p12
<a id=table-certs-req title="Table 1. Certs Requirements">

<!--
*Note:* The field **DNS:pihole.home.lan,DNS:pihole,IP:192.168.1.20**
is a single string with no spaces. It was broken into two lines only to fit in the table.
-->

We will show step by step how to create these certs using our simple script file `privca`.

!!! note
	Of course you can use any method or tools to create the certs as long as they fulfill the above specifications.  If you do so you may proceed directly to the step by step guide to certificate installation on and configuration of [Firefox](#install-certs-firefox) and [lighttpd](#steps-install-config-lighttpd).

#### Overview of each cert role

The combined key+cert files shown in the bottom row of [table 1](#table-cert-specs) are composed as follows:

##### Table 2: Combined certs {: id=table-combined-certs }

&nbsp;   | Key Part source file    | Cert Part source file | Combined File              
----     |----                     |----		   |----                        
Server   | Server1.key             | Server1.crt           | Server1.key-crt.pem 
Client   | Client1.key             | Client1.crt           | Client1.p12       

The next table shows to where the files will eventually be exported (server side or client side) and the role they will play (authenticator or authenticatee):

##### Table 3: Authenticatee/Authenticator Roles {: id=table-roles }

Authenticator      | Authenticatee  | Server side file           | Client side file 
----               |----            |----                        |----
Client             | Server         | Server1.key-crt.pem         | Root1.crt
Server             | Client         | Root1.crt                  | Client1.p12


<!-- -------------- ------- ----------------- -->

### Example of making certs with `privca` {: id=making-certs }

Step by step guide to creating the certs with [this simple script](privca-script).

#### certs step 1
On your main workstation, create a directory named *Root1* which will contain the private CA and all the leaf certificates that private CA issues.  
Then `cd` to that directory. E.g., `/etc/ssl/privca.d/Root1`

```
sudo mkdir /etc/ssl/privca.d/Root1
cd /etc/ssl/privca.d/Root1
```

#### certs step 2
Copy the *privca* shell script to that directory, (or place it somewhere in your path). 

It is available on [this page](privca-script), or you can download it from [gist](https://gist.github.com/craigphicks/c9dae527b30441730f62c9c9e9dab5a1) directly with

```
wget https://gist.githubusercontent.com/craigphicks/c9dae527b30441730f62c9c9e9dab5a1/raw/dfd43fff631850e6978a6769f82eba76ef6abe60/privca.sh
mv privca.sh privca
```

Make it executable:
```
sudo chmod +x privca
```
!!! note  
    For your reference there is a [man page for privca](privca).  
	Although it is not necessary for this example.


#### certs step 3
Create the CA cert.
```
./privca CreateCA Root1 MyOrg
```



#### certs step 4
Create the Server cert.
```
./privca CreateServer PiSrv DNS:pihole.home.lan,DNS:pihole,IP:192.168.1.20
```

Note: here it is assumed that you already have local DNS functionality to recognize *pihole.home.lan* and *pihole*.  Test any address, including the IP, with `ping`.  If not you might be able to use your `/etc/hosts` file to link the name and address for DNS.

#### certs step 5
Create the Client cert.  Prepare a password to set for the `.p12` certificate.  You will need to use it again when uploading the certificate to Firefox browser.  Hit return only to set no password.
```
./privca CreateClient Client1
<interactively enter password>
```

#### certs step 6
Confirm the diretory tree looks like this:
```
# tree
.
├── ca
│   ├── private
│   │   └── Root1.key
│   └── public
│       └── Root1.crt
├── export
│   ├── private
│   │   ├── Client1.p12
│   │   └── Server1.key-crt.pem
│   └── public
│       └── Root1.crt -> ./ca/public/Root1.crt
├── private
│   ├── Client1.key
│   └── Server1.key
├── public
│   ├── Client1.crt
│   └── Server1.crt
└── temp
    ├── Client1.csr
    └── Server1.csr

9 directories, 11 files
```

In our example configuration the files under
the **export** directory will be used for configuration.


<!-- ----------------------------------------------- -->


### Install certs on Firefox {: id=install-certs-firefox }

From Firefox -

Click through

```
Preferences | Privacy & Security | View Certificates | Authorities | Import
```

to upload

```
./export/ca/public/Root1.crt
```

Then click through

```
Preferences | Privacy & Security | View Certificates | Your Certificates | Import
```

to upload

```
./export/private/Root1.p12
```

When uploading, Firefox will ask you for the password you set when creating it, if any.

### Install certs and configure for `lighttpd` {: id=steps-install-config-lighttpd }

!!! note 
	Our summary of relevant *lighttpd* documentation is [here](#lighttpd-doc-summary), 
	although it is not necessary for following this step by step guide.

#### install step 2

Copy files to the serving device running *lighttpd* -

Source                                      | Dest Dir
----                                        |----
./export/ca/public/Root1.crt              | /etc/lighttpd/ssl/public/
./export/private/Server1.key-crt.pem  | /etc/lighttpd/ssl/private/

(The destinations can be freely chosen, this is just an example).

Set the destination owner and permission as follows - 

Dir or File                                           | owner:group   | perm
----                                                  |----           |----
/etc/lighttpd/ssl/public/                             | root:www-data | 755
/etc/lighttpd/ssl/public/Root1.crt                  | root:www-data | 644
/etc/lighttpd/ssl/private/                            | root:www-data | 750
/etc/lighttpd/ssl/private/Server1.key-crt.pem   | root:www-data | 640

These settings allow read access by `www-data` when serving.


<!-- ----------------------------------------------- -->


#### install step 3

Configure an existing *lighttpd* configuration file where it configures the *https* port *443*.
This might be in a file `/etc/lighttpd/external.conf`.

In the case that *lighttpd* is already configured for *https* one-way authentication, then modify/add the following parameter settings to achieve our two-way authentication:
```
  $SERVER["socket"] == ":443" {
    ...
    ssl.pemfile = "/etc/lighttpd/ssl/private/Server1.key-crt.pem"
    ssl.ca-file =  "/etc/lighttpd/ssl/public/Root1.crt"
    ...
    ssl.verifyclient.activate = "enable"
    ssl.verifyclient.enforce = "enable"
    ssl.verifyclient.depth = "2"
    ssl.verifyclient.username = "SSL_CLIENT_S_DN_CN"
	}
```

In the case that *lighttpd* is not yet configured for *https* one-way authentication, then here is an example of settings for *https* two-way authentication:

```
$HTTP["host"] =~ "pihole($|\.home\.lan)" {
  # Ensure the Pi-hole Block Page knows that this is not a blocked domain
  # PIHOLE APPLICATION SPECIFIC - ignore otherwise
  #setenv.add-environment = ("fqdn" => "true")

  # Enable the SSL engine with a LE cert, only for this specific host
  $SERVER["socket"] == ":443" {
    ssl.engine = "enable"
    ssl.pemfile = "/etc/lighttpd/ssl/Server1.key-crt.pem"
    ssl.ca-file =  "/etc/lighttpd/ssl/public/Root1.crt"
    ssl.honor-cipher-order = "enable"
    ssl.cipher-list = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
    ssl.use-sslv2 = "disable"
    ssl.use-sslv3 = "disable"
    # client side authentification       
    ssl.verifyclient.activate = "enable"
    ssl.verifyclient.enforce = "enable"
    ssl.verifyclient.depth = "10"
    ssl.verifyclient.username = "SSL_CLIENT_S_DN_CN"
###    ssl.verifyclient.username = "SSL_CLIENT_S_DN_emailAddress"
	}

  # Redirect HTTP to HTTPS
  $HTTP["scheme"] == "http" {
    $HTTP["host"] =~ ".*" {
      url.redirect = (".*" => "https://%0$0")
    }
  }
}
```

> Note: The above two-way setting were adapted from
[these one-way settings using an LE cert]
(https://discourse.pi-hole.net/t/enabling-https-for-your-pi-hole-web-interface/5771).

<!-- ----------------------------------------------- -->

#### install step 4

Now create a new additional *lighttpd* configuration file
```
sudo nano /etc/lighttpd/conf-available/02-auth-cert.conf
```
with content
```
# comment out the next line to silence warnings if "mod_auth" already loaded
server.modules += ("mod_auth")
auth.require = ( "" =>
                 (
                   "method"  => "extern",
                   "realm"   => "certificate",
                   "require" => "user=Client1" 
                 )
               )
```

Note: To allow multiple client IDs, separate by `|` and prefix each ID with `user=`, e.g.,:

```
                  "require" => "user=Client1|user=Client2" 

```


<!-- ----------------------------------------------- -->

#### install step 5

Restart the lighttpd daemon -
```
systemctl restart lighttpd
```
or
```
service lighttpd restart
```

Check the status is OK -
```
systemctl status lighttpd
```
or
```
service lighttpd status
```

<!-- ----------------------------------------------- -->

#### install step 6

Test access of the server from the Firefox browser, e.g., enter the address `pihole.home.lan` or `192.168.1.20` into the address bar.  On the first access Firefox will put up a dialog box for you to confirm the client certificate `Client1.p12`.  If you don't see the dialog box hunt around for it.  I once found it in another workspace under an already existing window.

<!-- ----------------------------------------------- -->

#### install step 7

Add more clients and servers to the network using the same CA, if required.

<!-- ----------------------------------------------- -->



<!-- ----------------------------------------------- -->

## Summary of *lighttpd* documentation on two-way authorization {: id=lighttpd-doc-summary }

A step by step guide to configuring *lighttpd* with the certs you created is given in
given [above](#install-lighttpd) in Install steps 2 through 4.  This section is only for reference.


The lighttpd [SSL documentation](https://redmine.lighttpd.net/projects/lighttpd/wiki/Docs_SSL)
describes the relevant parameters for one-way authentication:

Option                        |   Description
--------------                |----------
ssl.engine 	              | enable/disable ssl engine 
ssl.pemfile                   | path to the PEM file for SSL support (must contain both certificate and private key)
ssl.ca-file 	              | path to the CA file for support of chained certificates 

These additional parameters for two-way authentication, i.e. "Client Side Verification", are also described:

Option                        |   Description
--------------                |----------
ssl.verifyclient.activate     | enable/disable client verification
ssl.verifyclient.enforce      | enable/disable enforcing client verification
ssl.verifyclient.depth        | certificate depth for client verification
ssl.verifyclient.username     | client certificate entity to export as env:REMOTE_USER (eg. SSL_CLIENT_S_DN_emailAddress, SSL_CLIENT_S_DN_UID, etc.)

Setting

    ssl.verifyclient.username = SSL_CLIENT_S_DN_CN
    
will make  the "Common Name" of the client certificate available.

We want to use this "Common Name" for authentification in the *lighttpd* server itself,
and not just pass the value to an application.  The [Mod_Auth documentation](https://redmine.lighttpd.net/projects/lighttpd/wiki/Docs_ModAuth) describes how to do this:

```
auth.require = ( "" =>
                 (
                   "method"  => "extern",
                   "realm"   => "certificate",
                   "require" => "user=agent007|user=agent008" 
                 )
               )
```



!!! tldr "TLDR: Special Note on the parameter `ssl.ca-file`"
	The documentation states purpose as *"path to the CA file for support of chained certificates"*. That statement doesn't match with the roles show in [table Authenticatee/Authenticator Roles](#table-roles)  Probably this sentence was written thinking only of the case Server Authentication, where the server is the Authenticee holding a leaf secret-key & cert, and the client is the Authenticator holding the root CA public cert.

	In that case, and when when there is an intermediate certificate between the Server's held cert and the client's held root CA cert, purely as a matter of convenience the server will hold and pass the intermediate to the client as part of the SSL handshare.  And to make it even more convenient, the server will hold a copy the root which the client should already have a copy of.  It is necessary the client use their own trusted copy of the root CA for final confirmation.

	The intermediate plus root cert is usually bundled together in file named shomething like "blahblah-fullchain.pem", and `ssl.ca-file` is set to point to that file on the server.

	When there is no intermediate certificate involved, 
	and the client held root CA cert has directly issued the server held key+cert, 
	the server is not required to hold the root CA to pass to the client, 
	Server Authentication can succeed with parameter `ssl.ca-file` left unset. 
	(Tested by the author.)  

	On the other hand, in the case of Client Side Authentification, the parameter `ssl.ca-file` must point to a file holding the CA root certificate at the top of the trust chain which has issed the client's leaf certificate. This is a logical necessity.

	The author has only tested these cases:
	
    - Server Authetication only, with LE 3-level cert.
    - Server Authetication only, with private 2-level cert.
    - Server and Client Side Authentication, both with private 2-level certs, both issued by the same CA.

	Specifically the author hasn't tested other cases where multiple mixed roots and intermediates all must be present in the file pointed to by `ssl.ca-file`.  However the *lighttpd* documentation does specifically say it is possible.


## Comments are Welcome {: id=comments}

<form>
<div>
<script data-isso="https://pindertek.net/isso-2/"
        src="js-isso/embed.dev.js"></script>
<section id="isso-thread"></section>
</div>
</form>




<!-- ----------------------------------------------- -->
<!-- ----------------------------------------------- -->
<!-- ----------------------------------------------- -->
<!-- ----------------------------------------------- -->

<!--
-->

