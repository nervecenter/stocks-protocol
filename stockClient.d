//================================================ file = stockClient.d =====
//=  Program to request desired stock value from stockServer                =
//===========================================================================
//=  Build: Download the latest DMD from http://dlang.org/download.html     =
//=         In a command line, run:                                         =
//=             dmd stockClient.d                                           =
//=-------------------------------------------------------------------------=
//=  Execute: On Unix:      ./stockClient                                   =
//=           On Windows:   ./stockClient.exe or .\stockClient.exe          =
//=-------------------------------------------------------------------------=
//=  Authors: Christopher Collazo & Andres Pico                             =
//=           University of South Florida                                   =
//===========================================================================

//----- File imports --------------------------------------------------------
import std.stdio,
    std.socket,
    std.outbuffer,
    std.string;

//----- Function imports ----------------------------------------------------
import std.conv : to;
import core.time : dur;
    
//----- Constants -----------------------------------------------------------
enum PORT_NUM = 1050;             // Port number used at the server
enum IP_ADDR = "127.0.0.1".dup;   // IP address of server

//----- Functions -----------------------------------------------------------

/*
==================== 
constructRequest

  Presents a menu to select an action, and then returns the proper request
  string by recursing into the proper function.
==================== 
*/
string constructRequest()
{
    while (1)
    {
        writeln("\nWelcome to GetStock. Please select an option:");
        writeln("1) Register your username");
        writeln("2) Unregister your username");
        writeln("3) Request stock quotes");
        writeln("4) Send command \"QQQ,Joe,IBM;\"");
        writeln("5) Quit");
        write("Enter an option: ");
        int option = readln().strip().to!int();

        switch (option)
        {
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

/*
==================== 
registerCommand

  Asks for a username to register, returns the command to send.
==================== 
*/
string registerCommand()
{
    writeln("\nEnter a username to register: ");
    string username = readln().strip();
    return "REG," ~ username ~ ";";
}

/*
==================== 
unregisterCommand

  Asks for a username to unregister, returns the command to send.
==================== 
*/
string unregisterCommand()
{
    writeln("\nEnter a username to unregister: ");
    string username = readln().strip();
    return "UNR," ~ username ~ ";";
}

/*
==================== 
quoteCommand

  Asks for a registered username to request with, then continuously 
  accepts strings typed by the user as stock names; returns a 
  constructed request when the user types "done".
==================== 
*/
string quoteCommand()
{
    writeln("\nEnter a registered username to request with: ");
    string username = readln().strip();

    string[] stockNames;
    writeln("\nEnter a series of stock tickers to request quotes for, ");
    writeln("press enter after each one. Type \"done\" to finish.");

    string command = "QUO," ~ username;

    while (1)
    {
        string ticker = readln().strip().toUpper();
        if (ticker == "DONE") { break; }
        command ~= ("," ~ ticker);
        stockNames ~= ticker;
    }

    return command ~ ";";
}

//===== Main program ========================================================
void main() 
{
    Socket                  clientSocket;
    InternetAddress         serverAddress;
    Address                 serverAddressPlain;
    OutBuffer               sendBuffer;
    ubyte[4096]             receiveBuffer;
    int                     retryCounter;
    ptrdiff_t               bytesSent;
    ptrdiff_t               bytesReceived;
    string[]                stockNames;
    string[]                stockNumbers;
    string                  clientCommand;
    string                  serverSent;
    string                  serverResponseCode;
        
    clientSocket = new Socket(AddressFamily.INET, SocketType.DGRAM, ProtocolType.UDP);
    clientSocket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));

    write("Enter the IP of the server: ");
    char[] serverIP = readln.strip().dup;
    serverAddress = new InternetAddress(serverIP, PORT_NUM);
    serverAddressPlain = cast(Address)serverAddress;

    while (1) {
        // Clear our buffers for safety
        destroy(sendBuffer);
        destroy(receiveBuffer);

        // Get the message to send from the user
        string request = constructRequest();
        if (request == "quit") { break; }
        
        // Write our request into the send buffer; pull the command and if 
        // it's a quote command, pull the stock names from it for later listing
        sendBuffer = new OutBuffer();
        sendBuffer.write(request);
        clientCommand = request[0..3];
        if (request[0..3] == "QUO") 
        { 
            stockNames = request.chomp(";").split(',')[2..$]; 
        }

        // Send our message. If we receive nothing back, 
        bytesSent = clientSocket.sendTo(sendBuffer.toBytes(), serverAddress);
        if (bytesSent == Socket.ERROR)
        {
            writeln("*** ERROR - sendTo() failed ");
            return;
        }

        bytesReceived = Socket.ERROR;
        retryCounter = 1;
        while (bytesReceived == Socket.ERROR)
        {
            bytesReceived = clientSocket.receiveFrom(receiveBuffer, serverAddressPlain);
            if (bytesReceived > 0 || retryCounter == 3) { break; }

            writeln("Timed out. Retrying...");
            bytesSent = clientSocket.sendTo(sendBuffer.toBytes(), serverAddress);
            if (bytesSent == Socket.ERROR)
            {
                writeln("*** ERROR - sendTo() failed ");
                return;
            }
            retryCounter += 1;
        }

        if (retryCounter == 3) 
        { 
            writeln("\nNo response from the server."); 
            continue; 
        }
        
        serverSent = cast(string)receiveBuffer[0..bytesReceived];
        if (serverSent[$-1] != ';') 
        { 
            writeln("Message was corrupted, no semicolon."); 
            continue; 
        }
        serverResponseCode = serverSent[0..3];

        writeln();
        
        switch (serverResponseCode) {
            case "ROK": 
                if(clientCommand == "QUO")
                {
                    stockNumbers = serverSent[4..$-1].split(',');
                    writeln("Requested stock(s): ");

                    foreach (i, s; stockNumbers)
                    {
                        if (s == "-1") 
                        {
                            writeln(stockNames[i], ": Not a valid stock ticker.");
                        }
                        else 
                        {
                            writeln(stockNames[i], ": ", s);
                        }
                    }
                }
                else if(clientCommand == "REG")
                {
                    writeln("User was registered successfully.");
                }
                else if(clientCommand == "UNR")
                {
                    writeln("User was unregistered successfully.");
                }
                break;
            
            case "INC": 
                writeln("Invalid command."); break;
            
            case "INP": 
                writeln("Invalid parameters."); break;
            
            case "UAE": 
                writeln("User already exists."); break;
            
            case "UNR": 
                writeln("User does not exist."); break;
            
            case "INU": 
                write("Username cannot be longer than 32 characters");
                writeln("or include non-ASCII characters."); break;
            
            default:
                writeln("Message was corrupted.");
        }
    }
    
    // Close the client socket
    clientSocket.shutdown(SocketShutdown.BOTH);
    clientSocket.close();
    
    writeln("Exiting...");
}
