import std.stdio,
    std.socket,
    std.outbuffer,
    std.string,
    core.thread;

ushort PORT_NUM = 1050;             // Port number used at the server
char[] IP_ADDR = "127.0.0.1".dup;   // IP address of server

void main() {
    Socket                  client_s;        // Client socket descriptor
    InternetAddress         server_addr;     // Server Internet address
    OutBuffer               out_buf;         // Output buffer for data
    string                  out_str;         // String to be read in
    ubyte[]                 in_buf;          // Input buffer for data

    // Create a client socket
    try {
        client_s = new Socket(AddressFamily.INET, SocketType.DGRAM, ProtocolType.UDP);
    } catch (SocketException e) {
        writeln("*** ERROR - socket() failed ");
        return;
    }

    // Set options
    client_s.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));

    // Fill-in the server's address information and do a connect with the
    server_addr = new InternetAddress(IP_ADDR, PORT_NUM);

    string[] messages = [];
    messages ~= "REG,Joe;";
    messages ~= "REG,Suzy;";
    messages ~= "REG,JOE;";
    messages ~= "REG,Joe,Joe,Joe;";
    messages ~= "QUO,joe,IBM;";
    messages ~= "QUO,joe,IBM,FB;";
    messages ~= "QUO,joe,IBM,FBX;";
    messages ~= "QUO,joe;";
    messages ~= "QUO,joex,IBM;";
    messages ~= "QUO,joejoejoejoejoejoejoejoejoejoejoejoejoejoejoe,IBM;";
    messages ~= "QQQ,Joe,IBM;";
    messages ~= "REG,Joe,IBM;"; // Timeout test, three times, 5 seconds each
    messages ~= "UNR,JOE;";
    messages ~= "QUO,joe,IBM,FB;";

    foreach (m; messages) {
        Thread.sleep(dur!("seconds")(10)); 
        destroy(out_buf);
        destroy(in_buf);

        //Read in message to send
        out_buf = new OutBuffer();
        out_buf.write(m);

        // Send to the server using the client socket
        writeln("Sending message: ", m);
        ptrdiff_t bytesout = client_s.sendTo(out_buf.toBytes(), server_addr);
        if (bytesout == Socket.ERROR)
        {
            writeln("*** ERROR - sendTo() failed ");
            return;
        }
        writeln("Sent.");

        ptrdiff_t bytesin = client_s.receiveFrom(in_buf);
        
        //After receiving message successfully
        //if (received[$] != ";") { return "INP;" }
        string received = cast(string)in_buf;
        
        writeln("Got from server: ", received);
    }

    // Close the client socket
    client_s.shutdown(SocketShutdown.BOTH);
    client_s.close();
    
    writeln("Done.");
}
