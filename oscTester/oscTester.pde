import controlP5.*;
import oscP5.*;
import netP5.*;


OscP5 oscP5;
NetAddress myRemoteLocation;
ControlP5 controlP5;

int myColorBackground = color(0,0,0);
//int knobValue = 100;

CheckBox led;
CheckBox device;


int time = 3;
int value = 3;

void setup()
{
  size(400, 400);
  smooth();
  controlP5 = new ControlP5(this);

//  controlP5.addKnob("knob",100,200,128,100,160,40);
//  controlP5.addKnob("knobValue",0,255,128,100,240,40);
  device = controlP5.addCheckBox("device",40,40);
  led = controlP5.addCheckBox("led",40,80);
  device.setItemsPerRow(8);
  device.setSpacingColumn(20);
  led.setItemsPerRow(8);
  led.setSpacingColumn(20);
 
  for(int i = 0; i < 5; i++)
    device.addItem("" + i, 1 << i);

  for(int i = 0; i < 32; i++)
    led.addItem("" + i, 1 << i);
  
  controlP5.addSlider("time",0,65535,128,40,160,10,100);
  controlP5.addSlider("value",0,4095,128,140,160,10,100);

  controlP5.addButton("submit",1,0,300,400,100);
  
  myRemoteLocation = new NetAddress("localhost",15000);
  oscP5 = new OscP5(this,15001);
}

void draw()
{
  background(myColorBackground);
//  fill(knobValue);
//  rect(0,0,width,100);
}


void submit(int buttonValue) {
  int deviceValue = 0;
  for(int i = 0; i < 5; i++)
    deviceValue += (device.arrayValue()[i] != 0 ? 1 : 0) << i;

  int ledValue1 = 0, ledValue2 = 0;
  for(int i = 0; i < 16; i++) {
    ledValue1 += (led.arrayValue()[i] != 0 ? 1 : 0) << i;
    ledValue2 += (led.arrayValue()[16 + i] != 0 ? 1 : 0) << i;
  }
    
  println("submit:" + deviceValue + " " + ledValue1 + " " + ledValue2 + " " + value + " " + time);
  
  int device = deviceValue;
  int target1 = ledValue1;
  int target2 = ledValue2;
  int data = (value << 16) + time;

  println("submit raw:" + target1 + " / " + target2 + " / " + data);

  OscMessage message = new OscMessage("/tlc");
  
  message.add(device); /* add an int to the osc message */
  message.add(target1); /* add an int to the osc message */
  message.add(target2);
  message.add(data); /* add an int to the osc message */

  /* send the message */
  oscP5.send(message, myRemoteLocation); 

}

