import processing.serial.*;

import com.rapplogic.xbee.api.XBee;
import com.rapplogic.xbee.api.XBeeAddress64;
import com.rapplogic.xbee.api.XBeeException;
import com.rapplogic.xbee.api.XBeeTimeoutException;
import com.rapplogic.xbee.api.RemoteAtResponse;
import com.rapplogic.xbee.api.RemoteAtRequest;

import com.rapplogic.xbee.api.ApiId;
import com.rapplogic.xbee.api.AtCommand;
import com.rapplogic.xbee.api.AtCommandResponse;
import com.rapplogic.xbee.api.XBeeResponse;
import com.rapplogic.xbee.api.zigbee.NodeDiscover;

import oscP5.*;
import netP5.*;


String mySerialPort = "/dev/tty.usbserial-A600eLw9";
XBee xbee = new XBee();
int error = 0;
final int[] START_BYTES = { 0x22, 0x75 };

XBeeAddress64[] addresses = {
  new XBeeAddress64(0x0, 0x13, 0xa2, 0x0, 0x40, 0x69, 0x2d, 0x71),
  new XBeeAddress64(0x0, 0x13, 0xa2, 0x0, 0x40, 0x6e, 0x8b, 0xce),
  new XBeeAddress64(0x0, 0x13, 0xa2, 0x0, 0x40, 0x69, 0x2d, 0x1c),
};

int command = 'h';

ArrayList nodes = new ArrayList();

float lastNodeDiscovery;

int prevReceive = 0;

OscP5 oscP5;
NetAddress remote;

//-----------------------------------------------------------------
void setup()
{
  PropertyConfigurator.configure(dataPath("") + "log4j.properties");
  println("Available ports:");
  println(Serial.list());
  
  try
  {
    xbee.open(mySerialPort, 115200);
    println("\n===== successfully opend connection to XBee =====\n");
  }
  catch (XBeeException e)
  {
    println("** XBee port open error: " + e + " **");
    error = 1;
  }
  
  oscP5 = new OscP5(this, 15000);
  remote = new NetAddress("localhost", 15001);
  /*
  int value = 4095;
  int[] bytes = toBytes(value);
  println(bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3]);
  */
  
//  int[] payload = new int[] { command };
//  XBeeAddress64 addr64 = addresses[0];
//  ZNetTxRequest tx = new ZNetTxRequest(addr64, payload);
//  try
//  {
//    ZNetTxStatusResponse res = (ZNetTxStatusResponse) xbee.sendSynchronous(tx);
//    
//    println(res.isSuccess());
//  }
//  catch (XBeeException e)
//  {
//    
//  }
  
  //command = 'h' == command ? 'l' : 'h';
  //fdelay(1000);
}

//-----------------------------------------------------------------
void draw()
{  
  
  try
  {
    XBeeResponse response = xbee.getResponse(500);
    
    //XBeeResponse response = xbee.getResponse();
    if (!(response.isError()) && (response.getApiId() == ApiId.ZNET_RX_RESPONSE)) {
        ZNetRxResponse zrRes = (ZNetRxResponse) response;
        
        println("Received a sample from " + zrRes.getRemoteAddress64());

        int[] data = zrRes.getData();
        for (int i = 0; i < data.length; i++)
        {
          println("raw data " + i + " is -> " + data[i]);
        }
        int val = (data[0] << 8) + data[1];
        println("val is " + val);

        /*
        println("millis " + millis());
        println("prevs " + prevReceive);x
        if ((val < 100) && (millis() - prevReceive > 3000)) {
          XBeeAddress64 addr64 = addresses[2];
          int[] payload = {0x00, 0x07, 0x8b, 0x01, 0x28, 0xf7, 0x00, 0x00, 0x00, 0x54};
          ZNetTxRequest tx = new ZNetTxRequest(addr64, payload);
          try
          {
            ZNetTxStatusResponse res = (ZNetTxStatusResponse) xbee.sendSynchronous(tx);
            if (res.isSuccess())
            {
              println("\n===== successfully remove data =====\n");
            }
          }
          catch(Exception e) {
          }
        } else {   
          prevReceive = millis(); 
        }
        */
    }
  }
  catch (XBeeException e)
  {
    
  }
  
//  if (millis() - lastNodeDiscovery > 15 * 60 * 1000)
//  {
//    nodeDiscovery();
//    lastNodeDiscovery = millis();
//  }
}

//-----------------------------------------------------------------
void nodeDiscovery()
{
  long nodeDiscoveryTimeout = 6000;
  nodes.clear();
  
  print("cleared node list, looking up nodes...");
  
  try
  {
    println("sending node discover command");
    
    xbee.sendAsynchronous(new AtCommand("ND"));
    long startTime = millis();
    
    while (millis() - startTime < nodeDiscoveryTimeout)
    {
      try
      {
        XBeeResponse res = (XBeeResponse) xbee.getResponse(1000);
        if (res.getApiId() == ApiId.AT_RESPONSE)
        {
          NodeDiscover node = NodeDiscover.parse((AtCommandResponse)res);
          nodes.add(node);
          println("node discover response is: " + node);
        }
      }
      catch (XBeeTimeoutException e)
      {
        print(".");
      }
    }
  }
  catch (Exception e)
  {
    println("unexpected error " + e);
  }
  println("Node Discovery Completed");
  println("number of nodes: " + nodes.size());
}

//-----------------------------------------------------------------
void oscEvent(OscMessage msg)
{
  if (msg.checkAddrPattern("/tlc"))
  {
    println("- received OSC message: " + msg);
    int target = msg.get(0).intValue();
    int value  = msg.get(1).intValue();
    
    int[] payload = prependStartBytes(concat(toBytes(target), toBytes(value)));
    print("- data: ");
    for (int i = 0; i < payload.length; ++i)
    {
      if (payload.length - 1 != i)
        print(payload[i] + ":");
      else
        print(payload[i]);
    }
    println("");
    XBeeAddress64 addr64 = addresses[0];
    ZNetTxRequest tx = new ZNetTxRequest(addr64, payload);
    try
    {
      ZNetTxStatusResponse res = (ZNetTxStatusResponse) xbee.sendSynchronous(tx);
      if (res.isSuccess())
      {
        println("\n===== successfully sent data =====\n");
      }
    }
    catch (XBeeException e)
    {
      
    }
  }
}

//-----------------------------------------------------------------
int[] toBytes(int value)
{
  int[] b = new int[4];
  b[0] = ((value & 0xFF000000) >> 24);
  b[1] = ((value & 0xFF0000) >> 16);
  b[2] = ((value & 0xFF00) >> 8);
  b[3] = (value & 0xFF);

  return b;
}

//-----------------------------------------------------------------
int[] prepend(int[] values, int val)
{
  return splice(values, val, 0);
}

//-----------------------------------------------------------------
int[] prependStartBytes(int[] values)
{
  if (START_BYTES[0] == values[0] && START_BYTES[1] == values[1])
  {
    return values;
  }
  return concat(START_BYTES, values);
}

//-----------------------------------------------------------------
int[] insertDataLength(int[] values)
{
  int[] temp = new int[values.length];
  arrayCopy(values, temp);
  if (START_BYTES[0] != temp[0] && START_BYTES[1] != temp[1])
  {
    temp = prependStartBytes(temp);
  }
  
  return splice(temp, temp.length - START_BYTES.length, 2);
}



//-----------------------------------------------------------------
class Node
{
  XBeeAddress64 addr64;
  String address;
  boolean state = false;
  
  Node(XBeeAddress64 _addr64)
  {
    addr64 = _addr64;
    String[] hexAddress = new String[addr64.getAddress().length];
    for (int i = 0; i < addr64.getAddress().length; ++i)
    {
      hexAddress[i] = String.format("%02x", addr64.getAddress()[i]);
    }
    address = join(hexAddress, ":");
    println("Sender address: " + address);
  }
  
  void getState()
  {
    try
    {
      println("node to query: " + addr64);
      
      RemoteAtRequest req = new RemoteAtRequest(addr64, "D0");
      RemoteAtResponse res = (RemoteAtResponse)xbee.sendSynchronous(req, 10000);
      
      if (res.isOk())
      {
        int[] resArr = res.getValue();
        int resInt = (int)(resArr[0]);
        
        if (resInt == 4 || resInt == 5)
        {
          state = boolean(resInt - 4);
          println("successfully got state " + state + " for pin 20 (D0)");
        }
        else
        {
          println("unsupported setting " + resInt + " on pin 20 (D0)");
        }
      }
      else
      {
        throw new RuntimeException("failed to get state for pin 20. " + " state is " + res.getStatus());
      }
    }
    catch (XBeeTimeoutException e)
    {
      println("XBee request timed out. Check remote's configuaration, " + " range and power");
    }
    catch (Exception e)
    {
      println("unexpected error: " + e + "  Error text: " + e.getMessage());
    }
  }
  
  void toggleState()
  {
    state = !state;
    try
    {
      int[] command = { 4 };
      if (state) command[0] = 5;
      else command[0] = 4;
      
      RemoteAtRequest req = new RemoteAtRequest(addr64, "D0", command);
      RemoteAtResponse res = (RemoteAtResponse) xbee.sendSynchronous(req, 10000);
      
      if (res.isOk())
      {
        println("toggled pin 20 (D0) on node " + address);
      }
      else
      {
        throw new RuntimeException("failed to toggle pin 20.  status is " + res.getStatus());
      }
    }
    catch (XBeeTimeoutException e)
    {
      println("XBee request timed out. Check remote's " + "configuaration, range and power");
      state = !state;
    }
    catch (Exception e)
    {
      println("unexpected error: " + e + "  Error text: " + e.getMessage());
      state = !state;
    }
  }
}
