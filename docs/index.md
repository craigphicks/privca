---
layout: default
title: index page
---

[This page](./index.md) is at localtion ./index.md


Background: What is "two-way authentication" and "private CA" ?
-------------

Skip this section if you already know the terms "two-way authentication" and "private CA".

{% collapsible %}

One-way authentication is the most familiar model: that's the system of provable trust that allows the green lock followed by *https://...* to be displayed in the browser address bar.  The magic of [public cryptography](https://en.wikipedia.org/wiki/Public-key_cryptography) makes possible the system whereby a client requests a URL, and then receives authentication data from a server saying "I am the one allowed to serve this URL", and it is believable be\
cause a CA (certificate authority) will vouch for it.  Of course the response URL had better match the requested URL -  otherwise you may be p*wned!

Two way authentication is an additional step where the server also receives authentication data from the client.  However, there are some subtle differences.  Firstly, instead of a URL it is an ID which is being verified.  Secondly,  the server does not request the ID first - the client initiates contact and then the server verifies that the client ID is on a list of allowed clients.  Nevertheless, the core algorithms behind authenticating the ID and aut\
henticating the URL are the same, and most (but not all) of the procedural glue is the same.  This additional step is also called "client side verification"

Last but not least, two-way authentication is for situations where the servers and clients which will be communicating with each other are known in advance at the time the certificates are issued.  Therefore two-way authentication is not applicable to general public browsing.  Two-way authentication is a niche use case for secure, closed membership systems.

A private CA is also created for use on a secure, closed membership system.  A private CA is not globally known.  A private CA and two-way authentication are well suited to each other because they handle the same niche use case.

{% endcollapsible %}


