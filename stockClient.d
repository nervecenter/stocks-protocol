import std.stdio,
    std.socket,
    std.outbuffer,
    std.string;

ushort PORT_NUM = 1050;             // Port number used at the server
char[] IP_ADDR = "127.0.0.1".dup;   // IP address of server

void main() {
    Socket                  client_s;        // Client socket descriptor
    InternetAddress         server_addr;     // Server Internet address
    OutBuffer               out_buf;         // Output buffer for data
    string                  out_str;         // String to be read in
    ubyte[140]              in_buf;          // Input buffer for data

    // Create a client socket
    try {
        client_s = new Socket(AddressFamily.INET, SocketType.DGRAM, ProtocolType.UDP);
    } catch (SocketException e) {
        writeln("*** ERROR - socket() failed ");
        exit(-1);
    }

    // Set options
    client_s.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));

    // Fill-in the server's address information and do a connect with the
    server_addr = new InternetAddress(IP_ADDR, PORT_NUM);

    while (1) {
        destroy(out_buf);
        destroy(in_buf);

        //Read in message to send
        out_buf = new OutBuffer();
        writeln("Write 140 character message to send:");
        out_str = readln();
        out_str = strip(out_str);
        if (out_str.length > 140) {
            writeln("No longer than 140 characters, please.");
            continue;
        }
        out_buf.write(out_str);

        // Send to the server using the client socket
        write("Sending message...");
        ptrdiff_t bytesout = client_s.sendTo(out_buf.toBytes(), server_addr);
        if (bytesout == Socket.ERROR)
        {
            writeln("*** ERROR - sendTo() failed ");
            exit(-1);
        }
        writeln("Sent.");

        // Wait to receive a message for 5 seconds, else resend
        ptrdiff_t bytesin = client_s.receiveFrom(in_buf);
        if (bytesin == 0) {
            writeln("No bytes received. Exiting");
            return;
        }
        else if (bytesin == Socket.ERROR) {
            writeln("*** ERROR - receiveFrom() failed.");
            return;
        }

        // Output the received message
        writefln("Received from server: %s", cast(char[])in_buf);
    }

    // Close the client socket
    client_s.shutdown(SocketShutdown.BOTH);
    client_s.close();
    
    writeln("Done.");
}