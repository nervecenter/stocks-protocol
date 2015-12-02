//================================================ file = stockServer.d =====
//=  Program to act as server for requesting stocks from                    =
//===========================================================================
//=  Build: Download the latest DMD from http://dlang.org/download.html     =
//=         In a command line, run:                                         =
//=             dmd stockServer.d                                           =
//=-------------------------------------------------------------------------=
//=  Execute: On Unix:      ./stockServer                                   =
//=           On Windows:   ./stockServer.exe or .\stockServer.exe          =
//=-------------------------------------------------------------------------=
//=  Authors: Christopher Collazo & Andres Pico                             =
//=           University of South Florida                                   =
//===========================================================================

//----- File imports --------------------------------------------------------
import std.stdio,
    std.socket,
    std.outbuffer,
    std.regex,
    std.string;

//----- Function imports ----------------------------------------------------
import std.file :       exists;
import std.algorithm :  remove;
import std.algorithm :  canFind;

//----- Constants -----------------------------------------------------------
enum PORT_NUM = 1050;

//----- Functions -----------------------------------------------------------

/*
==================== 
createReply

  Read the client's message and determine what to do, 
  recursing into the proper function.
==================== 
*/
string createReply(string clientSent, ref string[] userList, string[string] stockList) 
{
    if (clientSent[$-1] != ';') { return "INP;"; }

    string[] parameters = clientSent.chomp(";").split(',');
    string clientCommand = parameters[0];
    string username = parameters[1].toUpper();
    if (username.length > 32) { return "INU;"; }

    writeln("User connected: ", username);

    switch (clientCommand)
    {
        case "REG":
            if (parameters.length > 2) { return "INP;"; }
            return registerUsername(username, userList);

        case "UNR":
            if (parameters.length > 2) { return "INP;"; }
            return unregisterUsername(username, userList);

        case "QUO":
            if (parameters.length < 3) { return "INP;"; }
            return stockNumbers(username, parameters[2..$], stockList, userList);

        default:
            return "INC;";
    }
}

/*
==================== 
isUserRegistered

  Check if the user is registered and return a bool indicating so.
==================== 
*/
bool isUserRegistered(string username, string[] userList) 
{
    foreach (u; userList) 
    {
        if (u == username) 
        {
            return true;
        }
    }
    return false;
}

/*
==================== 
stockNumbers

  On a quote command, get the requested stock ticker numbers 
  and send them back.
==================== 
*/
string stockNumbers(string username, string[] requestedStocks, string[string] stockList, string[] userList)
{
    if (!isUserRegistered(username, userList)) { return "UNR;"; }
    if (requestedStocks.length < 1) { return "INP;"; }

    string reply = "ROK";
    foreach (name; requestedStocks) 
    {
        reply ~= ",";
        if (name in stockList) 
        {
            reply ~= stockList[name];
        } 
        else 
        {
            reply ~= "-1";
        }
    }
    return reply ~ ";";
}

/*
==================== 
registerUsername

  Take a requested username, make sure it's valid, then register it,
  saving the updated user list to file.
==================== 
*/
string registerUsername(string username, ref string[] userList) 
{
    if (isUserRegistered(username, userList)) { return "UAE;"; }

    auto m = matchAll(username, regex(`[A-Z0-9]{1,32}`));
    string match = m.front.hit;
    // If the whole username didn't match our regular expression, it's invalid
    if (match != username) { return "INU;"; }

    writeln("New valid username matched: ", match);
    userList ~= username;

    File f = File("userList.txt", "w");
    foreach (u; userList) { f.writeln(u); }

    return "ROK;";
}

/*
==================== 
unregisterUsername

  Take a designated username, make sure it's on the list, then 
  unregister it, saving the updated user list to file.
==================== 
*/
string unregisterUsername(string username, ref string[] userList) 
{
    if (!isUserRegistered(username, userList)) { return "UNR;"; }

    foreach (i, u; userList) 
    {
        if (u == username) 
        {
            userList = userList[0..i] ~ userList[i + 1..$]; 
            break;
        }
    }

    File f = File("userList.txt", "w");
    foreach (u; userList) { f.writeln(u); }

    return "ROK;";
}

//===== Main program ========================================================
void main() 
{
    UdpSocket           serverSocket;
    Address             clientAddress;
    ubyte[4096]         receiveBuffer;
    OutBuffer           sendBuffer;
    ptrdiff_t           bytesReceived;
    ptrdiff_t           bytesSent;
    string              clientSent;
    string              serverReply;
    string[]            userList;
    string[string]      stockList;

    // Open our users if it exists and drop it in our users array
    if (exists("userList.txt")) 
    {
        File f = File("userList.txt", "r");
        string user;
        
        while ((user = f.readln().strip()) !is null) 
        {
            userList ~= user;
        }
    }

    // Open our stocks if it exists and drop it in our stocks dictionary
    if (exists("stockList.txt")) 
    {
        File f = File("stockList.txt", "r");
        string stock;
        
        while ((stock = f.readln().strip()) !is null) 
        {
            string[] nameAndVal = stock.split(',');
            stockList[nameAndVal[0]] = nameAndVal[1];
        }
    }

    serverSocket = new UdpSocket();
    serverSocket.bind(new InternetAddress(InternetAddress.ADDR_ANY, PORT_NUM));

    while(1) 
    {
        // Clear our buffers for safety
        destroy(sendBuffer);
        destroy(receiveBuffer);
        
        writeln("\nListening...");
        bytesReceived = serverSocket.receiveFrom(receiveBuffer, clientAddress);
        if (bytesReceived == 0 || bytesReceived == Socket.ERROR) 
        {
            writeln("*** ERROR - receiveFrom() failed: ", bytesReceived);
            return;
        }

        writeln("IP address of client = ", clientAddress.toAddrString(), 
                "  port = ", clientAddress.toPortString());

        clientSent = cast(string)receiveBuffer[0..bytesReceived];
        writeln("Received from client: ", clientSent);

        serverReply = createReply(clientSent, userList, stockList);
        writeln("Sending back to client: ", serverReply);
        sendBuffer = new OutBuffer();
        sendBuffer.write(serverReply);

        write("Sending message....");
        bytesSent = serverSocket.sendTo(sendBuffer.toBytes(), clientAddress);
        if (bytesSent == Socket.ERROR) 
        {
            writeln("*** ERROR - sendTo() failed ");
            return;
        }
        writeln("Sent.");
    }

    serverSocket.shutdown(SocketShutdown.BOTH);
    serverSocket.close();
    
    writeln("Done.");
}

