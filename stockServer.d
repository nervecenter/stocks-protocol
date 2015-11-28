import std.stdio,
	std.socket,
	std.outbuffer,
	std.string,
	std.conv;

ushort PORT_NUM = 1050;

string parseMessage(string received) {
    if (received[$] != ";") { return "INP;" }

    string code = received[0..3];

    switch (code) {
        case "REG": return registerUsername(received[3..$-1]);
        case "UNR": return unregisterUsername(received[3..$-1]);
        case "QUO":
            string[] parts = received[3..$-1].split(',');
            string username = parts[0];
            string[] stockNames = parts[1..$];
            return stockNumbers(user, stockNames);
        default:
            return "INC;";
    }
}

string stockNumbers(string username, string[] stockNames) {
    if (!verifiedUser(username)) { return "UNR;"; }

    string reply = "ROK,";

    foreach (name; stockNames) {
        reply ~= ",";
        // Look through the stock list
        // If it's there, append the value casted to a string
        // If not, append string "-1"
        reply ~= "-1";
    }

    return reply ~ ";";
}

bool verifiedUser(string username) {
    // Comb through username list
    // If username found, return true
    // If username not found, return false
}

void main() {
	UdpSocket       server_s;        // Listen socket descriptor
  	Address 		client_addr;     // Client Internet address
  	ubyte[140]      in_buf;    		 // Input buffer for receiving data
  	OutBuffer 		out_buf;		 // Output buffer for sending data
  	ptrdiff_t 		bytesin;		 // Number of bytes we receive, for checking error
    string[]        usernames;
    string[][]      stocks;

    // Open our usernames file
    if (!exists("usernames.txt")) { 
        write("usernames.txt", "");
        usernames = [];
    } else {
        usernames = readText("usernames.txt").split('\n');
    }

    // Open our stocks file
    stocks = [];
    if (!exists("stocks.txt")) { 
        write("stocks.txt", "");
    } else {
        string[] stocklines = readText("stocks.txt").split('\n');

        foreach (s; stocklines) {
            stocks ~= s.split(',');
        }
    }

	// Create our server socket as a UDP Internet socket
	try {
		server_s = new UdpSocket();
	} catch (SocketException e) {
		writeln("*** ERROR - server socket() failed ");
		return;
	}

	// Set options
	//server_s.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));
	//server_s.blocking(false);

	// Create our server address with the given port number, bind it to the socket
	try {
		server_s.bind(new InternetAddress(InternetAddress.ADDR_ANY, PORT_NUM));
	} catch(AddressException e) {
		writeln("*** ERROR - server bind() failed ");
		return;
	}

	while(1) {
		// Clear whatever is in the buffers
		destroy(out_buf);
		destroy(in_buf);
		
		// Listen for a message
		writeln("Waiting...\n");
		bytesin = server_s.receiveFrom(in_buf, client_addr);
		if (bytesin == 0 || bytesin == Socket.ERROR) {
			writeln("*** ERROR - receiveFrom() failed ");
			return;
		}

		// Send the message and client address to the reply thread in a message
		// Print an informational message of IP address and port of the client
		writeln("IP address of client = ", client_addr.toAddrString(), 
				"  port = ", client_addr.toPortString());

		// Output the received message
		writefln("Received from client: %s", cast(char[])in_buf);

		// Create response
		string to_send = "Greeting from the server!";
		writefln("Sending back to client: %s", to_send);

		// Allocate a new buffer on the heap, fill it
		out_buf = new OutBuffer();
		out_buf.write(to_send);

		// Send our message
		write("Sending message....");
		ptrdiff_t bytesout = server_s.sendTo(out_buf.toBytes(), client_addr);
		if (bytesout == Socket.ERROR) {
			writeln("*** ERROR - sendTo() failed ");
			return;
		}
		writeln("Sent.");
	}

    // Write changes to file

	// Close our server socket
	server_s.shutdown(SocketShutdown.BOTH);
	server_s.close();
	writeln("Listen socket closed.");
	
	writeln("Done.");
}