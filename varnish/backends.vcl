backend b1 {
    .host = "127.0.0.1";
    .port = "80";
	.max_connections = 300; # That's it
	.probe = {
		#.url = "/"; # short easy way (GET /)
		# We prefer to only do a HEAD /
		.request = 
			"HEAD / HTTP/1.1"
			"Host: localhost"
			"Connection: close";      	
		.interval = 5s; # check the health of each backend every 5 seconds
		.timeout = 1s; # timing out after 1 second.
		# If 3 out of the last 5 polls succeeded the backend is considered healthy, otherwise it will be marked as sick
		.window = 5;
		.threshold = 3;
		}
	.first_byte_timeout     = 300s;   # How long to wait before we receive a first byte from our backend?
	.connect_timeout        = 5s;     # How long to wait for a backend connection?
	.between_bytes_timeout  = 2s;     # How long to wait between bytes received from our backend?
    
}

backend b2 {
    .host = "127.0.0.1";
    .port = "8080";
}

backend b3 {
    .host = "127.0.0.1";
    .port = "8080";
}

backend b4 {
    .host = "127.0.0.1";
    .port = "8080";
}


sub backends_init {
	new vdir = directors.round_robin();
	vdir.add_backend(b1);
	vdir.add_backend(b2);
	vdir.add_backend(b3);
	vdir.add_backend(b4);

}
