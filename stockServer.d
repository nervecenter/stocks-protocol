import std.stdio,
    std.socket,
    std.outbuffer,
    std.conv,
    std.regex,
    std.string;
import std.file :       exists;
import std.algorithm :  remove;

ushort PORT_NUM = 1050;

string createReply(string received, ref string[] userList, string[][] stockList) {
    if (received[$-1] != ';') { 
        debug writeln("No semicolon. Index: ", received.indexOf(';'), " Length: ", received.length); 
        return "INP;"; 
    }

    string[] parameters = received
                            .chomp(";")
                            .split(',');
    string code = parameters[0];
    string username = parameters[1].capitalize();

    switch (code) {
        case "REG":
            if (parameters.length > 2) { 
                debug writeln("Too many params for register."); 
                return "INP;"; 
            }
            return registerUsername(username, userList);

        case "UNR":
            if (parameters.length > 2) { 
                debug writeln("Too many params for unregister."); 
                return "INP;"; 
            }
            return unregisterUsername(username, userList);

        case "QUO":
            if (parameters.length < 3) { 
                debug writeln("Too few params for quote."); 
                return "INP;"; 
            }
            return stockNumbers(username, parameters[2..$], stockList, userList);

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
    foreach (u; userList) {
        if (u == username) {
            return true;
        }
    }
    return false;
}

string registerUsername(string username, ref string[] userList) {
    auto m = matchAll(username, regex(`[A-Z0-9]{1,32}`));
    if (m.front.hit != username) {
        return "INU;";
    }
    foreach (u; userList) {
        if (username == u) {
            return "UAE;";
        }
    }
    userList ~= username;
    return "ROK;";
}

string unregisterUsername(string username, ref string[] userList) {
    foreach (u; userList) {
        if (username == u) {
            userList.remove(u);
            return "ROK;";
        }
    }
    return "UNR;";
}

void main() {
    UdpSocket       server_s;        // Listen socket descriptor
    Address         client_addr;     // Client Internet address
    ubyte[]         in_buf;          // Input buffer for receiving data
    OutBuffer       out_buf;         // Output buffer for sending data
    ptrdiff_t       bytesin;         // Number of bytes we receive, for checking error
    string[]        userList;
    string[][]      stockList;

    // Open our stocks file
    userList = [];
    if (exists("userList.txt")) {
        File f = File("userList.txt", "r");
        string user;
        
        while ((user = f.readln()) !is null) {
            userList ~= user;
        }
    }

    // Open our stocks file
    stockList = [];
    if (exists("stockList.txt")) {
        File f = File("stockList.txt", "r");
        string stock;
        
        while ((stock = f.readln()) !is null) {
            stockList ~= stock.split(',');
        }
    }

    server_s = new UdpSocket();
    server_s.bind(new InternetAddress(InternetAddress.ADDR_ANY, PORT_NUM));
    //server_s.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));
    //server_s.blocking(false);


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
        writefln("Sending back to client: %s", reply);

        // Allocate a new buffer on the heap, fill it
        out_buf = new OutBuffer();
        out_buf.write(reply);

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
    File f = File("userList.txt", "w");
    foreach (u; userList) {
        f.writeln(u);
    }

    f = File("stockList.txt", "w");
    foreach (s; stockList) {
        f.writeln(s[0] ~ "," ~ s[1]);
    }

    server_s.shutdown(SocketShutdown.BOTH);
    server_s.close();
    
    writeln("Done.");
}

