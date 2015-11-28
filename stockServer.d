import std.stdio,
    std.socket,
    std.outbuffer,
    std.string,
    std.conv,
    std.regex,
    std.file,
    std.algorithm;

ushort PORT_NUM = 1050;

string createReply(string received, ref string[] userList, string[][] stockList) {
    if (received[$] != ';') { return "INP;"; }

    string[] parameters = received
                            .chomp(";")
                            .split(',');
    string code = parameters[0];

    switch (code) {
        case "REG":
            if (parameters.length > 2) { return "INP;"; }
            return registerUsername(parameters[1], userList);

        case "UNR":
            if (parameters.length > 2) { return "INP;"; }
            return unregisterUsername(parameters[1], userList);

        case "QUO":
            if (parameters.length < 3) { return "INP;"; }
            return stockNumbers(parameters[1], parameters[2..$], stockList, userList);

        default:
            return "INC;";
    }
}

string stockNumbers(string username, string[] reqStocks, string[][] stockList, string[] userList) {
    if (!verifiedUser(username, userList)) { return "UNR;"; }
    if (reqStocks.length < 1) { return "INP;"; }

    string reply = "ROK,";
    foreach (name; reqStocks) {
        reply ~= ",";
        foreach (s; stockList) {
            if (s[0] == name) {
                reply ~= s[1];
            } else {
                reply ~= "-1";
            }
        }
    }
    return reply ~ ";";
}

bool verifiedUser(string username, string[] userList) {
    string ucap = username.capitalize();
    foreach (u; userList) {
        if (u == ucap) {
            return true;
        }
    }
    return false;
}

string registerUsername(string username, ref string[] userList) {
    string ucap = username.capitalize();
    auto m = matchAll(ucap, regex(`[A-Z0-9]{1,32}`));
    if (m.front.hit != ucap) {
        return "INU;";
    }
    foreach (u; userList) {
        if (ucap == u) {
            return "UAE;";
        }
    }
    userList ~= ucap;
    return "ROK;";
}

string unregisterUsername(string username, ref string[] userList) {
    string ucap = username.capitalize();
    foreach (u; userList) {
        if (ucap == u) {
            userList.remove(u);
            return "ROK;";
        }
    }
    return "UNR;";
}

void main() {
    UdpSocket       server_s;        // Listen socket descriptor
    Address         client_addr;     // Client Internet address
    ubyte[140]      in_buf;          // Input buffer for receiving data
    OutBuffer       out_buf;         // Output buffer for sending data
    ptrdiff_t       bytesin;         // Number of bytes we receive, for checking error
    string[]        userList;
    string[][]      stockList;

    // Open our list of users file
    if (!exists("userList.txt")) { 
        write("userList.txt", "");
        userList = [];
    } else {
        userList = readText("userList.txt").split('\n');
    }

    // Open our stocks file
    stockList = [];
    if (!exists("stockList.txt")) { 
        write("stockList.txt", "");
    } else {
        string[] stocklines = readText("stockList.txt").split('\n');

        foreach (s; stocklines) {
            stockList ~= s.split(',');
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
        writefln("Received from client: %s", cast(string)in_buf);

        // Create response
        string reply = createReply(cast(string)in_buf, userList, stockList);
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
    remove("userList.txt");
    foreach (u; userList) {
        write("userList.txt", u ~ "\n");
    }

    remove("stockList.txt");
    foreach (s; stockList) {
        write("stockList.txt", s[0] ~ "," ~ s[1] ~ "\n");
    }

    server_s.shutdown(SocketShutdown.BOTH);
    server_s.close();
    
    writeln("Done.");
}

