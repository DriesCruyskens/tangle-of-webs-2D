import controlP5.*;
import processing.svg.*;

ControlP5 cp5;
Web web;
boolean record;

void setup() {
  pixelDensity(1);
  size(1240, 1748);

  reset();

  cp5 = new ControlP5(this);

  cp5.addSlider("forceMultiplier")
    .setPosition(10, 10)
    .setRange(0, 2)
    .plugTo(web);

  cp5.addSlider("edgeLengthThresh")
    .setPosition(10, 50)
    .setRange(0, 1000)
    .plugTo(web);

  //cp5.addToggle("drawHamiltonian")
  //  .setPosition(100, 200)
  //  .plugTo(web)
  //  //.setSize(40, 40).setMode(ControlP5.SWITCH)
  //  ;
}

void reset() {
  web = new Web();
}

void draw() {
  if (record) {
    String timestamp = year() + nf(month(), 2) + nf(day(), 2) + "-"  + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
    beginRecord(SVG, "prints/"+ timestamp + ".svg");
  }

  background(#071013);
  web.render();

  if (record) {
    endRecord();
    record = false;
  }
}

void keyPressed() {
  if (key == ' ') {
    reset();
  }
  if (keyCode == RIGHT) {
    for (int i = 0; i <20; i++) {
      web.generateEdge();
      for (int j = 0; j <20; j++) {
        web.applyForce();
      }
    }
  }
  if (key == 's') {
    record = true;
  }
}
