<!-- privca-man -->

Step by step usage example is [here](../#making-certs).

## *privca* usage description

To keep user required actions to a minumum, the simple bash script *privca* satisfies the following conditions:

- No configuration files are used, minimal command line parameters only.
- Two levels of certificates only, no intermediate certificates.
- Certificate file names correspond to their certificate "Common names", and leaf "common names" include their CA "common names"

The program must be executed in the directory which will be used for certificate storage.  
Typically the directory would have the same name as the root CA common name.
The certificate file owner will be set the program executor.
All calls should made by the same executor, e.g., all as user, or all as sudo.

##### privca CreateCA

<strong>privca CreateCA &lt;*CA common name*&gt; &lt;*CA organization name*&gt;</strong>

 - Only one CA is allowed per directory.
 - No password is used for the CA private key.  To enable it, modify the *privca* source to remove argument *-nodes* in the call to *openssl* in the function `CreateCA`.
 - <strong>&lt;*CA common name*&gt;</strong> will be the CA common name parameter, which will also be used in the file name.  No spaces or non-filename characters should be used.
 - <strong>&lt;*CA organization name*&gt;</strong> is only used as a category index by the Firefox browser.  If you create multiple CA's and always use the same CA organization name, then the various CA's with different common names will appear together under the shared organization name in the browser's *Authorities* list.
 - The following files will be created:
    - <strong>&lt;*Server common name*&gt;.key</strong> : the CA private key
    - <strong>&lt;*Server common name*&gt;.crt</strong> : the CA public cert

##### privca CreateServer

<strong>privca CreateServer &lt;*Server common name*&gt; &lt;*subjectAltNames*&gt;</strong>

 - The CA must have been already created.  It will be used.
 - <strong>&lt;*Server common name*&gt;</strong> will be the sever common name parameter, and that will also be used in the filename.  No spaces or non-filename character should be used.
 - <strong>&lt;*subjectAlNames*&gt;</strong> will be the `subjectAltNames` field in the certificate.  This is set to the the addresses that will appear in the browser bar, e.g., `DNS:pihole.home.lan,DNS:pihole,IP:192.168.1.20`.
 - The following files will be created:
    - <strong>&lt;*Server common name*&gt;.key</strong> : server private key file 
    - <strong>&lt;*Server common name*&gt;.crt</strong> : server public cert
    - <strong>&lt;*Server common name*&gt;.key-crt.pem</strong> : combined key and cert
  A file <strong>&lt;*Server common name*&gt;.key-crt.pem</strong> will be created.  This file needs to copied to and configured by the *lighttpd* server with the `ssl.pem-file` parameter.  It functions as the server certificate.
  
##### priv CreateClient

<strong>privca CreateClient &lt;*Client common name*&gt;</strong>

 - The CA must have been already created.  It will be used.
 - <strong>&lt;*Client common name*&gt;</strong> will be the common name parameter, and that will also be used for the filename. No spaces or non-filename character should be used.
 - The following files will be created:
    - <strong>&lt;*Client common name*&gt;.key</strong> : server private key file 
    - <strong>&lt;*Client common name*&gt;.crt</strong> : server public cert
    - <strong>&lt;*Client common name*&gt;.pks12</strong> : combined key and cert

<description markdown=1>
An example final directory tree:

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

