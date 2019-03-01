
<!-- site_name: Two way SSL authentication in a private network - example is shown using Lighttpd and Firefox -->

<details><summary>
## Summary
</summary>

Client Side Authentification is the counterpart to Server Authentication in HTTPS, together making Two-way Authentication.  Using a private CA (Certificate Authority) to issue both Server and Client certificates is a sensible approach.  This document provides a step-by-step example where *lighttpd v1.4.45* is server, and Firebox Browser v65.0 is client.

</details>

<!-- ----------------------------------------------- -->

<details><summary>
## *lighttpd* documentation on two-way security
</summary>

The lighttpd [SSL documentation](https://redmine.lighttpd.net/projects/lighttpd/wiki/Docs_SSL)
describes the relevant parameters for one-way authentication:

Option                        |   Description
--------------                |----------
ssl.engine 	              | enable/disable ssl engine 
ssl.pemfile                   | path to the PEM file for SSL support (must contain both certificate and private key)
ssl.ca-file 	              | path to the CA file for support of chained certificates 

The additional parameters for two-way authentication, i.e. "Client Side Verification", are also described:

Option                        |   Description
--------------                |----------
ssl.verifyclient.activate     | enable/disable client verification
ssl.verifyclient.enforce      | enable/disable enforcing client verification
ssl.verifyclient.depth        | certificate depth for client verification
ssl.verifyclient.username     | client certificate entity to export as env:REMOTE_USER (eg. SSL_CLIENT_S_DN_emailAddress, SSL_CLIENT_S_DN_UID, etc.)

Searching with `site:redmine.lighttpd.net SSL_CLIENT_S_DN_C` shows that

    ssl.verifyclient.username = SSL_CLIENT_S_DN_CN
    
is a valid value, and will make  the "Common Name" of the client certificate available.

We want to use this "Common Name" for authentification in the *lighttpd* server itself, not act upon the value in the application.  The [Mod_Auth documentation](https://redmine.lighttpd.net/projects/lighttpd/wiki/Docs_ModAuth) describes how to do this:

```
auth.require = ( "" =>
                 (
                   "method"  => "extern",
                   "realm"   => "certificate",
                   "require" => "user=agent007|user=agent008" 
                 )
               )
```

Putting all this information together will be covered in
section [iwozere](#fullexample)

<details><summary>
### Special Note on the parameter `ssl.ca-file`
</summary>

The documentation states purpose as *"path to the CA file for support of chained certificates"*.  Probably this stentence was written thinking only of the case Server Authentication, where the server is the Authenticee holding a leaf secret-key & cert, and the client is the Authenticator holding the root CA public cert.

In that case, and when when there is an intermediate certificate between the Server's held cert and the client's held root CA cert, purely as a matter of convenience the server will hold and pass the intermediate to the client as part of the SSL handshare.  And to make it even more convenient, the server will hold a copy the root which the client should already have a copy of.  It is necessary the client use their own trusted copy of the root CA for final confirmation.

The intermediate plus root cert is usually bundled together in file named shomething like `blahblah-fullchain.pem", and `ssl.ca-file` is set to point to that file on the server.

When there is no intermediate certificate involved, and the client held root CA cert has directly 
issued the server held key+cert, the server is not required to hold the root CA to pass 
to the client, Server Authentication can succeed with parameter `ssl.ca-file` left unset. 
(Tested by the author.)  

On the other hand, in the case of Client Side Authentification, the parameter `ssl.ca-file` must point to a file holding the CA root certificate at the top of the trust chain which has issed the client's leaf certificate. This is a logical necessity.

The author has only tested these cases:
 - Server Authetication only, with LE 3-level cert.
 - Server Authetication only, with private 2-level cert.
 - Server and Client Side Authentication, both with private 2-level certs, both issued by the same CA.

Specifically the author hasn't tested other cases where multiple mixed roots and intermediates all must be present in the file pointed to by `ssl.ca-file`.  However the *lighttpd* documentation does specifically say it is possible.

</details>
</details>

<!-- ----------------------------------------------- -->

<details><summary>
## <a name="fullexample"></a> Full example with *lighttpd v1.4.45* and *Firefox v65.0*
</summary>

<details><summary>
### step 1
</summary>

Create one private root and two leaf certificates with the following profiles:

Property          | CA cert        |  Server cert                                       |  Client cert
------------------|----------------|-------------                                       |----
type              | CA             | Leaf                                               |  Leaf
CN (common name)  | Root1          | Server1                                            | Client1
subjectAltName    | N/A            | DNS:pihole.home.lan,<br>DNS:pihole,IP:192.168.1.20 | N/A
Key filename      | Root1.key      | Server1.key                                        | Client1.key
Cert filname      | Root1.crt      | Server1.crt                                        | Client1.crt 
Key+Cert filename | N/A            | Server1.key-crt.pem                                | Client1.p12

*Note:* The field **DNS:pihole.home.lan,DNS:pihole,IP:192.168.1.20**
is a single string with no spaces. It was broken into two lines only to fit in the table.

There are a number of programs capable for creating such files, but for convenience and brevity
a humble minimalist batch file calling making *openssl* calls is provided with this document.
It is described in the section [*privca* Cert Creation Tool]().
</details>

<details><summary>
### Pause for Bird's Eye View
</summary>

We pause for a birds eye view of what files go where, and what role they
play in the web of Authentication.

The key+cert files are composed as follows:

&nbsp;   | Key Part source file    | Cert Part source file | Combined File              
----     |----                     |----		   |----                        
Server   | Server1.key             | Server1.crt           | Server1.key-crt.pem 
Client   | Client1.key             | Client1.crt           | Client1.p12       

The next table shows to where the files will eventually be exported and the role they will play:

Authenticator      | Authenticatee  | Server side file           | Client side file 
----               |----            |----                        |----
Client             | Server         | Server1.key-crt.pem         | Root1.crt
Server             | Client         | Root1.crt                  | Client1.p12

</details>

<!-- ----------------------------------------------- -->

<details><summary>
### step 6
</summary>
From Firefox -

Click through
```
Preferences | Privacy & Security | View Certificates | Authorities | Import
```
to upload
```
./export/ca/public/HomeLan.crt
```

Then click through
```
Preferences | Privacy & Security | View Certificates | Your Certificates | Import
```
to upload
```
./export/private/Client1--HomeLan.p12
```
When uploading, Firefox will ask you for the password you set when creating it, if any.
</details>
<!-- ----------------------------------------------- -->


<details><summary>
### step 7
</summary>
Copy files to the serving device running *lighttpd* -

Source                                      | Dest Dir
----                                        |----
./export/ca/public/HomeLan.crt              | /etc/lighttpd/ssl/public/
./export/private/PiSrv-HomeLan.key-crt.pem  | /etc/lighttpd/ssl/private/

(The destinations can be freely chosen, this is just an example).

Set the destination owner and permission as follows - 

Dir or File                                           | owner:group   | perm
----                                                  |----           |----
/etc/lighttpd/ssl/public/                             | root:www-data | 755
/etc/lighttpd/ssl/public/HomeLan.crt                  | root:www-data | 644
/etc/lighttpd/ssl/private/                            | root:www-data | 750
/etc/lighttpd/ssl/private/PiSrv-HomeLan.key-crt.pem   | root:www-data | 640

These settings allow read access by `www-data` when serving.
</details>
<!-- ----------------------------------------------- -->


<details><summary>
### step 8
</summary>
Configure an existing *lighttpd* configuration file where it configures the *https* port *443*.
This might be in a file `/etc/lighttpd/external.conf`.

In the case that *lighttpd* is already configured for *https* one-way authentication, then modify/add the following parameter settings to achieve our two-way authentication:
```
  $SERVER["socket"] == ":443" {
    ...
    ssl.pemfile = "/etc/lighttpd/ssl/private/PiSrv--HomeLan.key-crt.pem"
    ssl.ca-file =  "/etc/lighttpd/ssl/public/HomeLan.crt"
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
    ssl.pemfile = "/etc/lighttpd/ssl/PiSrv--HomeLan.key-crt.pem"
    ssl.ca-file =  "/etc/lighttpd/ssl/public/HomeLan.crt"
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
Note: The above two-way setting were adapted from
[these one-way settings using an LE cert]
(https://discourse.pi-hole.net/t/enabling-https-for-your-pi-hole-web-interface/5771).

</details>
<!-- ----------------------------------------------- -->

<details><summary>
### step 9
</summary>
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
                   "require" => "user=Client1--HomeLan" 
                 )
               )
```

Note: To allow multiple client IDs, separate by `|` and prefix each ID with `user=", e.g.,:
```
                   "require" => "user=Client1--HomeLan|user=Client2--HomeLan" 
```
</details>

<!-- ----------------------------------------------- -->

<details><summary>
### step 10
</summary>
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
</details>

<!-- ----------------------------------------------- -->

<details><summary>
### step 11
</summary>
Test access of the server from the Firefox browser, e.g., enter the address `pihole.home.lan` or `192.168.1.20` into the address bar.  On the first access Firefox will put up a dialog box for you to confirm the client certificate `Client1--HomeLan.p12`.  If you don't see the dialog box hunt around for it.  I once found it in another workspace under an already existing window.
</details>

<!-- ----------------------------------------------- -->

<details><summary>
### step 12
</summary>
Add more clients and servers to the network using the same CA, if required.
</details>


</details>
<!-- ----------------------------------------------- -->


*privca* Cert Creation Tool
----------------------------
----------------------------

*privca* Usage Document
---------------------------

{% collapsible %}

To keep user required actions to a minumum, the simple bash script *privca* satisfies the following conditions:

 - No configuration files are used, minimal command line parameters only.
 - Two levels of certificates only, no intermediate certificates.
 - Certificate file names correspond to their certificate "Common names", and leaf "common names" include their CA "common names"

The program must be executed in the directory which will be used for certificate storage.  
Typically the directory would have the same name as the root CA common name.
The certificate file owner will be set the program executor.
All calls should made by the same executor, e.g., all as user, or all as sudo.

 - **privca.sh  CreateCA &lt;*CA common name*&gt; &lt;*CA organization name*&gt;**
  - Only one CA is allowed per directory.
  - No password is used for the CA private key.  To enable it, modify the *privca* source to remove argument *-nodes* in the call to *openssl* in the function `CreateCA`.
  - **&lt;*CA common name*&gt;** will be the CA common name parameter, which will also be used in the file name.  No spaces or non-filename characters should be used.
  - **&lt;*CA organization name*&gt;** is only used as a category index by the Firefox browser.  If you create multiple CA's and always use the same CA organization name, then the various CA's with different common names will appear together under the shared organization name in the browser's *Authorities* list.
  - The following files will be created:
   - **&lt;*Server common name*&gt;.key** : the CA private key
   - **&lt;*Server common name*&gt;.crt** : the CA public cert
 - **privca.sh CreateServer &lt;*Server common name*&gt; &lt;*subjectAltNames*&gt;**
  - The CA must have been already created.  It will be used.
  - **&lt;*Server common name*&gt;** will be the sever common name parameter, and that will also be used in the filename.  No spaces or non-filename character should be used.
  - The following files will be created:
   - **&lt;*Server common name*&gt;.key** : server private key file 
   - **&lt;*Server common name*&gt;.crt** : server public cert
   - **&lt;*Server common name*&gt;.key-crt.pem** : combined key and cert
  A file **&lt;*Server common name*&gt;.key-crt.pem** will be created.  This file needs to copied to and configured by the *lighttpd* server with the `ssl.pem-file` parameter.  It functions as the server certificate.
 - **privca.sh CreateClient &lt;*Client common name*&gt;**
  - The CA must have been already created.  It will be used.
  - **&lt;*Client common name*&gt;** will be the common name parameter, and that will also be used for the filename. No spaces or non-filename character should be used.
  - The following files will be created:
   - **&lt;*Client common name*&gt;.key** : server private key file 
   - **&lt;*Client common name*&gt;.crt** : server public cert
   - **&lt;*Client common name*&gt;.pks12** : combined key and cert

An example final directory tree:

{% codeblock %}
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
{% endcodeblock %}

{% endcollapsible %}

*privca* Source Code
---------------------------

{% collapsible %}
<script src="https://gist.github.com/craigphicks/c9dae527b30441730f62c9c9e9dab5a1.js"></script>

[Click here](https://gist.github.com/craigphicks/c9dae527b30441730f62c9c9e9dab5a1) if your broswer doesn't execute java script.

{% endcollapsible %}

*privca* Usage Example
---------------------------

**step 1**
On your main workstation, create a directory named *HomeLan* which will contain the private CA and all the leaf certificates that private CA issues.  
Then `cd` to that directory. E.g., `/etc/ssl/privca.d/HomeLan`

```
sudo mkdir /etc/ssl/privca.d/HomeLan
cd /etc/ssl/privca.d/HomeLan
```

**step 2**
Copy the *privca* shell script to that directory, (or place it somewhere in your path).  Make it executable.
```
wget https://gist.githubusercontent.com/craigphicks/c9dae527b30441730f62c9c9e9dab5a1/raw/dfd43fff631850e6978a6769f82eba76ef6abe60/privca.sh
sudo chmod +x privca.sh
```

**step 3**
Create the CA cert.
```
./privca CreateCA HomeLan MyOrg
```

**step 4**
Create the Server cert.
```
./privca CreateServer PiSrv DNS:pihole.home.lan,DNS:pihole,IP:192.168.1.20
```

Note: here it is assumed that you already have local DNS functionality to recognize *pihole.home.lan* and *pihole*.  Test any address, including the IP, with `ping`.

**step 5**
Create the Client cert.  Prepare a password to set for the `.p12` certificate.  You will need to use it again when uploading the certificate to Firefox browser.  Hit return only to set no password.
```
./privca CreateClient Client1
<interactively enter password>
```

**step 6**
Confirm the diretory tree looks like this:
{% codeblock %}
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
{% endcodeblock %}

If you are going using **lighttpd** as server, and **Firefox** as client, then the files under
the  **export** are the ones you will configure.  
That configuration walk-through is in section [


THE END
---





<!-- ----------------------------------------------- -->
<!-- ----------------------------------------------- -->
<!-- ----------------------------------------------- -->
<!-- ----------------------------------------------- -->

<!--
<details><summary>
</summary>
</details>
-->

