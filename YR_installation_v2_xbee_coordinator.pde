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

final String MODE_A = "A";
final String MODE_B = "B";
final String MODE_C = "C";
final String MODE_D = "D";
final String MODE_E = "E";

final int[] START_BYTES_FOR_MODE_A = { 0x22, 0x75 };
final int[] START_BYTES_FOR_MODE_B = { 0x22, 0x76 };
final int[] START_BYTES_FOR_MODE_C = { 0x22, 0x77 };
final int[] START_BYTES_FOR_MODE_D = { 0x22, 0x78 };
final int[] START_BYTES_FOR_MODE_E = { 0x22, 0x79 };

XBeeAddress64[] addresses = {
  new XBeeAddress64(0x0, 0x13, 0xa2, 0x0, 0x40, 0x69, 0x2d, 0x71),
  new XBeeAddress64(0x0, 0x13, 0xa2, 0x0, 0x40, 0x6e, 0x8b, 0xce),
  new XBeeAddress64(0x0, 0x13, 0xa2, 0x0, 0x40, 0x69, 0x2d, 0x1c),
  new XBeeAddress64(0x0, 0x13, 0xa2, 0x0, 0x40, 0x8a, 0x5a, 0x52),
  new XBeeAddress64(0x0, 0x13, 0xa2, 0x0, 0x40, 0x8a, 0x5a, 0x57),
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
  
}

//-----------------------------------------------------------------
void draw()
{
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
  println("\n=*=*=*=*=*=*=*=*= OscMessage received =*=*=*=*=*=*=*=*=");
  if (msg.checkAddrPattern("/tlc")) {
    String mode = msg.get(0).stringValue();
    int device = msg.get(1).intValue();
    int target1 = msg.get(2).intValue();
    int target2 = msg.get(3).intValue();
    int value  = msg.get(4).intValue();
    println("========== MODE = " + mode + " ===========");
    int[] payload = prependStartBytes(mode, concat(toBytes(device), concat(toBytes(target1), concat(toBytes(target2), toBytes(value)))));
    print("- data: ");
    for (int i = 0; i < payload.length; ++i) {
      if (payload.length - 1 != i)
        print(payload[i] + ":");
      else
        print(payload[i]);
    }
    println("");
    
    if (32 == device) {
      ZNetTxRequest tx = new ZNetTxRequest(XBeeAddress64.BROADCAST, payload);
      try {
        ZNetTxStatusResponse res = (ZNetTxStatusResponse) xbee.sendSynchronous(tx);
        if (res.isSuccess()) {
          println("\n===== Successfully sent data! Address = " + XBeeAddress64.BROADCAST + " =====\n");
        }
      } catch (XBeeException e) {
        println("\n===== ERROR!! =====\n" + e);
      }
    } else {
      for (int i = 0; i < 5; ++i) {
        if ((device & (1 << i)) != 0) {
          XBeeAddress64 addr64 = addresses[i];
          ZNetTxRequest tx = new ZNetTxRequest(addr64, payload);
          try {
            xbee.sendAsynchronous(tx);
//            ZNetTxStatusResponse res = (ZNetTxStatusResponse) xbee.sendSynchronous(tx);
//            if (res.isSuccess()) {
//              println("\n===== Successfully sent data! Address = " + addr64 + " =====\n");
//            }
          } catch (XBeeException e) {
            println("\n===== ERROR!! Device address = " + addr64 + " =====\n" + e);
          }
        }
      }
    }
   xbee.clearResponseQueue();
  }
  println("\n=*=*=*=*=*=*=*=*= OscMessage end =*=*=*=*=*=*=*=*=");
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
int[] prependStartBytes(String mode, int[] values)
{
  if (mode.equals(MODE_A)) {
    println("- mode A");
    if (START_BYTES_FOR_MODE_A[0] == values[0] && START_BYTES_FOR_MODE_A[1] == values[1]) {
      return values;
    } else {
      return concat(START_BYTES_FOR_MODE_A, values);
    }
  } else if (mode.equals(MODE_B)) {
    println("- mode B");
    if (START_BYTES_FOR_MODE_B[0] == values[0] && START_BYTES_FOR_MODE_B[1] == values[1]) {
      return values;
    } else {
      return concat(START_BYTES_FOR_MODE_B, values);
    }
  } else if (mode.equals(MODE_C)) {
    println("- mode C");
    if (START_BYTES_FOR_MODE_C[0] == values[0] && START_BYTES_FOR_MODE_C[1] == values[1]) {
      return values;
    } else {
      return concat(START_BYTES_FOR_MODE_C, values);
    }
  } else if (mode.equals(MODE_D)) {
    println("- mode D");
    if (START_BYTES_FOR_MODE_D[0] == values[0] && START_BYTES_FOR_MODE_D[1] == values[1]) {
      return values;
    } else {
      return concat(START_BYTES_FOR_MODE_D, values);
    }
  } else if (mode.equals(MODE_E)) {
    println("- mode E");
    if (START_BYTES_FOR_MODE_E[0] == values[0] && START_BYTES_FOR_MODE_E[1] == values[1]) {
      return values;
    } else {
      return concat(START_BYTES_FOR_MODE_E, values);
    }
  } else {
    println("- mode not found.");
    // default
    return concat(START_BYTES_FOR_MODE_A, values);
  }
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
