//================================================ file = stockClient.d =====
//=  Program to request desired stock value from server.		    		=
//===========================================================================
//=-------------------------------------------------------------------------=
//=  Example input:                                                         =
//=     REG, USERNAME;                                                      =
//=    	UNR, USERNAME;                                                      =
//=	    QUO, USERNAME, APPL;						    					=
//=	    QUO, USERNAME, APPL, FB;					    					=
//=-------------------------------------------------------------------------=
//=  Bugs: None known                                                       =
//=-------------------------------------------------------------------------=
//=  Build: dmd stockClient.d			                            		=
//=-------------------------------------------------------------------------=
//=  Execute: .\stockClient.d                                               =
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
	core.thread;

	
//----- Defines -------------------------------------------------------------
ushort PORT_NUM = 1050;             // Port number used at the server
char[] IP_ADDR = "127.0.0.1".dup;   // IP address of server


//===== Main program ========================================================
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
        return;
    }

    // Set options
    client_s.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));

    // Fill-in the server's address information and do a connect with the server
    server_addr = new InternetAddress(IP_ADDR, PORT_NUM);

    while (1) {
        destroy(out_buf);
        destroy(in_buf);

        //Read in message to send
        out_buf = new OutBuffer();
        writeln("Waiting for request:");
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
            return;
        }
        writeln("Sent.");

		
        // Wait to receive a message for 3 seconds, else resend
		ptrdiff_t bytesin = client_s.receiveFrom(in_buf);
		while (bytesin == 0 || bytesin == Socket.ERROR)
		{
			Thread.sleep( dur!("seconds")( 3 ) ); 
			writeln("");
			writeln("Retrying..");
			
			//Send message and receive again
			bytesout = client_s.sendTo(out_buf.toBytes(), server_addr);
			if (bytesout == Socket.ERROR)
			{
				writeln("*** ERROR - sendTo() failed ");
				return;
			}
			writeln("Sent.");
			bytesin = client_s.receiveFrom(in_buf);
		}
		
		//Output data received
		string received = cast(string)in_buf;
		string response = received[0..3];
		
		switch (response) {
			case "ROK": 
				string command = out_str[0..3];
				
				if(command == "QUO"){
					int i;
					string[] parts = received[4..$-1].split(',');
					string username = parts[0];
					write("Requested stock(s): ");
					
					for(i = 0; i < parts.length; ++i){
						username = parts[i];
						if(i == 0){
							write(username);
						}
						else{
							write(", ", username);
						}
					}
					writeln(".");
				}
				
				else if(command == "REG"){
					writeln("User was registered successfully");
				}
				
				else if(command == "UNR"){
					writeln("User was unregistered successfully");
				}
				continue;
			
			case "INC": 
				writeln("Invalid Command");
				continue;
			
			case "INP": 
				writeln("Invalid Parameters");
				continue;
			
			case "UAE": 
				writeln("User already exists");
				continue;
			
			case "UNR": 
				writeln("User does not exists");
				continue;
			
			case "INU": 
				writeln("Username cannot be longer than 32 characters or include non-ASCII characters");
				continue;
			
			default:
				writeln("Message was corrupted");
		}
    }
    
    // Close the client socket
    client_s.shutdown(SocketShutdown.BOTH);
    client_s.close();
    
    writeln("Client socket has been closed.");
}
