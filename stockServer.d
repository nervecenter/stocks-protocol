import std.stdio,
    std.socket,
    std.outbuffer,
    std.string,
    std.conv;

ushort PORT_NUM = 1050;

string parseMessage(string received, string[] userList, string[][] stocks) {
    if (received[$] != ";") { return "INP;" }

    string code = received[0..4];

    switch (code) {
        case "REG,": return registerUsername(received[4..$-1], userList);
        case "UNR,": return unregisterUsername(received[4..$-1], userList);
        case "QUO,":
            string[] parts = received[3..$-1].split(',');
            string username = parts[0];
            string[] reqStocks = parts[1..$];
            return stockNumbers(username, reqStocks, stocks);
        default:
            return "INC;";
    }
}

string stockNumbers(string username, string[] reqStocks, string[][] stocks) {
    if (!verifiedUser(username)) { return "UNR;"; }
    if (reqStocks.length < 1) { return "INP;" }

    string reply = "ROK,";

    foreach (name; reqStocks) {
        reply ~= ",";
        
        foreach (s; stocks) {
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
    foreach (u; userList) {
        if (u == username) {
            return true;
        }
    }
    return false;
}

string registerUsername(string username, userList) {
    string ucap = username.capitalize();
    RegexMatch m = matchAll(ucap, regex(`[A-Z0-9]{1,32}`));
    if (m.front.hit != ucap) {
        return "INU;";
    }
    foreach (u; userList) {
        if (ucap == u) {
            return "UAE;";
        }
    }
    
}

void main() {
    UdpSocket       server_s;        // Listen socket descriptor
    Address         client_addr;     // Client Internet address
    ubyte[140]      in_buf;          // Input buffer for receiving data
    OutBuffer       out_buf;         // Output buffer for sending data
    ptrdiff_t       bytesin;         // Number of bytes we receive, for checking error
    string[]        userList;
    string[][]      stocks;

    // Open our usernames file
    if (!exists("userList.txt")) { 
        write("userList.txt", "");
        userList = [];
    } else {
        userList = readText("userList.txt").split('\n');
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
        writefln("Received from client: %s", cast(string)in_buf);

        // Create response
        string reply = parseMessage(cast(string)in_buf, usernames, stocks);
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

    remove("stocks.txt");
    foreach (s; stocks) {
        write("stocks.txt", s[0] ~ "," ~ s[1] ~ "\n");
    }

    server_s.shutdown(SocketShutdown.BOTH);
    server_s.close();
    
    writeln("Done.");
}