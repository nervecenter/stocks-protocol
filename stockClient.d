//================================================ file = stockClient.d =====
//=  Program to request desired stock value from server.                    =
//===========================================================================
//=-------------------------------------------------------------------------=
//=  Example input:                                                         =
//=     REG, USERNAME;                                                      =
//=     UNR, USERNAME;                                                      =
//=     QUO, USERNAME, APPL;                                                =
//=     QUO, USERNAME, APPL, FB;                                            =
//=-------------------------------------------------------------------------=
//=  Bugs: None known                                                       =
//=-------------------------------------------------------------------------=
//=  Build: dmd stockClient.d                                               =
//=-------------------------------------------------------------------------=
//=  Execute: ./stockClient.d                                               =
//=-------------------------------------------------------------------------=
//=  Authors: Christopher Collazo & Andres Pico                             =
//=          University of South Florida                                    =
//=-------------------------------------------------------------------------=
//=  History: AP (11/28/15) - Started file                                  =
//===========================================================================


//----- Include files -------------------------------------------------------
import std.stdio,
    std.socket,
    std.outbuffer,
    std.string,
    core.thread,
    std.conv;

    
//----- Defines -------------------------------------------------------------
ushort PORT_NUM = 1050;             // Port number used at the server
char[] IP_ADDR = "127.0.0.1".dup;   // IP address of server

string constructRequest() {
    while (1) {
        writeln("\nWelcome to GetStock. Please select an option:");
        writeln("1) Register your username");
        writeln("2) Unregister your username");
        writeln("3) Request stock quotes");
        writeln("4) Send command \"QQQ,Joe,IBM;\"");
        writeln("5) Quit");
        write("Enter an option: ");
        int o = readln().strip().to!int();

        switch (o) {
            case 1:
                return registerCommand();
            case 2:
                return unregisterCommand();
            case 3:
                return quoteCommand();
            case 4:
                return "QQQ,Joe,IBM;";
            case 5:
                return "quit";
            default:
                writeln("Invalid command.");
        }
    }
}

string registerCommand() {
    writeln("\nEnter a username to register: ");
    string username = readln().strip();
    return "REG," ~ username ~ ";";
}

string unregisterCommand() {
    writeln("\nEnter a username to unregister: ");
    string username = readln().strip();
    return "UNR," ~ username ~ ";";
}

string quoteCommand() {
    writeln("\nEnter a registered username to request with: ");
    string username = readln().strip();

    string[] stockNames;
    write("Enter a series of stock tickers to quote, ");
    writeln("press enter after each one. Type \"done\" to finish.");

    string command = "QUO," ~ username;

    while (1) {
        string ticker = readln().strip().toUpper();
        if (ticker == "DONE") { break; }
        command ~= ("," ~ ticker);
        stockNames ~= ticker;
    }

    return command ~ ";";
}

//===== Main program ========================================================
void main() {
    Socket                  client_s;        // Client socket descriptor
    InternetAddress         server_addr;     // Server Internet address
    OutBuffer               out_buf;         // Output buffer for data
    ubyte[4096]             in_buf;          // Input buffer for data
    int                     counter;
    string[]                stockNames;
        
    client_s = new Socket(AddressFamily.INET, SocketType.DGRAM, ProtocolType.UDP);

    // Set options
    client_s.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));

    write("Enter the IP of the server: ");
    char[] server_ip = readln.strip().dup;

    // Fill-in the server's address information and do a connect with the server
    server_addr = new InternetAddress(server_ip, PORT_NUM);
    Address server_addr_plain = cast(Address)server_addr;

    while (1) {
        destroy(out_buf);
        destroy(in_buf);

        //Read in message to send
        out_buf = new OutBuffer();
        string request = constructRequest();
        if (request == "quit") { break; }
        out_buf.write(request);
        if (request[0..3] == "QUO") {
            stockNames = request.chomp(";").split(',')[2..$];
        }

        // Send to the server using the client socket
        debug write("\nSending message...");

        ptrdiff_t bytesout = client_s.sendTo(out_buf.toBytes(), server_addr);
        if (bytesout == Socket.ERROR)
        {
            writeln("*** ERROR - sendTo() failed ");
            return;
        }
        debug writeln("Sent.");
        counter = 1;

        // Wait to receive a message for 3 seconds, else resend
        ptrdiff_t bytesin = Socket.ERROR;
        while (bytesin == Socket.ERROR)
        {
            bytesin = client_s.receiveFrom(in_buf, server_addr_plain);
            if (bytesin > 0 || counter == 3) { break; }

            write("Retrying...");
            bytesout = client_s.sendTo(out_buf.toBytes(), server_addr);
            if (bytesout == Socket.ERROR)
            {
                writeln("*** ERROR - sendTo() failed ");
                return;
            }
            debug writeln("Sent.");
            counter += 1;
        }

        if (counter == 3) { writeln("\nNo response from the server."); continue; }
        
        string command = request[0..3];

        //Output data received
        string received = cast(string)in_buf[0..bytesin];
        debug writeln("Got message from server: ", received);
        if (received[$-1] != ';') { writeln("Message was corrupted."); continue; }

        string responseCode = received[0..3];
        writeln();
        
        switch (responseCode) {
            case "ROK": 
                if(command == "QUO"){
                    string[] stockNumbers = received[4..$-1].split(',');
                    debug writeln(stockNames, "\n", stockNumbers);
                    assert(stockNames.length == stockNumbers.length);
                    writeln("Requested stock(s): ");
                    
                    foreach (i, s; stockNumbers){
                        if (s == "-1") {
                            writeln(stockNames[i], ": Not a valid stock ticker.");
                        } else {
                            writeln(stockNames[i], ": ", s);
                        }
                    }
                }
                
                else if(command == "REG"){
                    writeln("User was registered successfully.");
                }
                
                else if(command == "UNR"){
                    writeln("User was unregistered successfully.");
                }
                continue;
            
            case "INC": 
                writeln("Invalid command.");
                continue;
            
            case "INP": 
                writeln("Invalid parameters.");
                continue;
            
            case "UAE": 
                writeln("User already exists.");
                continue;
            
            case "UNR": 
                writeln("User does not exist.");
                continue;
            
            case "INU": 
                writeln("Username cannot be longer than 32 characters or include non-ASCII characters.");
                continue;
            
            default:
                writeln("Message was corrupted.");
        }
    }
    
    // Close the client socket
    client_s.shutdown(SocketShutdown.BOTH);
    client_s.close();
    
    writeln("Exiting...");
}
