import java.util.*;
import java.util.Arrays;
import org.jgrapht.Graphs;
import org.jgrapht.Graph;

class Web {
  DefaultUndirectedGraph<PVector, DefaultEdge> g; //graph
  DefaultUndirectedGraph<PVector, DefaultEdge> gComplete;
  PVector[] c; // candidate line
  Map<PVector, DefaultEdge> intersectMap; // maps intersect points to the edge they are on
  ArrayList<PVector> startingNodes;
  List<PVector> hamiltonian;
  
  boolean drawHamiltonian = false;
  float forceMultiplier = .05;
  float edgeLengthThresh = 30;

  Web() {
    startingNodes = new ArrayList<PVector>();
    g = generateGraph();

    intersectMap = new TreeMap<PVector, DefaultEdge>(
      new Comparator<PVector>() {

      @Override
        public int compare(PVector o1, PVector o2) {
        if (o1.x < o2.x) return -1;
        if (o1.x > o2.x) return 1;
        return 0;
      }
    }
    );
    generateEdge();
  }

  void render() {
    // draw candidate
    if (!record) {
      stroke(#FF0000);
      line(c[1].x, c[1].y, c[0].x, c[0].y);
    }

    // draw vertices
    for (PVector p : g.vertexSet()) {
      fill(#000000);
      stroke(#000000);
      // ellipse(p.x, p.y, 5, 5);
    }

    // draw edges
    for (DefaultEdge e : g.edgeSet()) {
      PVector p1 = g.getEdgeSource(e);
      PVector p2 = g.getEdgeTarget(e);
      fill(#000000);
      stroke(#b1ede8);
      strokeJoin(ROUND);
      strokeCap(ROUND);
      strokeWeight(2);
      line(p1.x, p1.y, p2.x, p2.y);
    }

    // draw intersects
    if (!record) {
      for (PVector p : intersectMap.keySet()) {
        fill(#FF0000);
        stroke(#FF0000);
        ellipse(p.x, p.y, 10, 10);
      }
    }
    // draw curve hamiltonian
    if (drawHamiltonian && hamiltonian != null) {
      fill(#b1ede8);
      stroke(#b1ede8);
      beginShape();
      for (PVector p : hamiltonian) {
        curveVertex(p.x, p.y);
      }
      endShape();
    }
  }

  void hamiltonianPath() {
    gComplete = new DefaultUndirectedGraph<PVector, DefaultEdge>(DefaultEdge.class);
    for (PVector p1 : g.vertexSet()) {
      gComplete.addVertex(p1);
      for (PVector p2 : g.vertexSet()) {
        gComplete.addVertex(p2);
        if (!p1.equals(p2)) {
          gComplete.addEdge(p1, p2);
        }
      }
    }
    TwoApproxMetricTSP<PVector, DefaultEdge> h = new TwoApproxMetricTSP();
    hamiltonian = h.getTour(gComplete).getVertexList();
  }

  void applyForce() {
    DefaultUndirectedGraph<PVector, DefaultEdge> newg = new DefaultUndirectedGraph<PVector, DefaultEdge>(DefaultEdge.class);

    // we need a map from old to new pvector because we need to reconstruct the edges after computation
    // jgrapht does not allow changing existing nodes/PVectors x and y values (sees is as a new node not in the graph)
    Map<PVector, PVector> oldNewPositions = new HashMap<PVector, PVector>();

    // calculate new pos for each vertex and map them to the old point
    for (PVector p : g.vertexSet()) {

      // leave startingnodes in place
      boolean isStartingNode = false;
      for (PVector startingNode : startingNodes) {
        if (p.x == startingNode.x && p.y == startingNode.y) {
          isStartingNode = true;
        }
      }

      if (isStartingNode) {
        oldNewPositions.put(p, p);
        newg.addVertex(p);
        continue; // dont adjust starting nodes
      }

      // for all edges of a vertex: put their normalized directoin vector in a list
      ArrayList<PVector> vectorlist = new ArrayList<PVector>();

      for (DefaultEdge e : g.edgesOf(p)) {
        // for each edge: calculate normalized vector towards opposite node

        PVector opposite = Graphs.getOppositeVertex(g, e, p);

        // direction = destination - source
        PVector direction = PVector.sub(opposite, p);
        // only keep sufficiently long
        if (direction.mag() > edgeLengthThresh) {
          direction.normalize();
          vectorlist.add(direction);
        }
      }

      PVector sum = new PVector(0, 0);
      // sum all the normalized vectors in the vectorlist
      try {
        sum.set(vectorlist.get(0));
      }
      catch(Exception e) {
      }

      for (int j = 1; j < vectorlist.size(); j++) {
        sum.add(vectorlist.get(j));
      }

      // amount of movement multiplier
      sum.mult(forceMultiplier);

      // calculate new vertex position, map old to new position and add new postition to the new graph
      PVector newPosition = PVector.add(p, sum);
      oldNewPositions.put(p, newPosition);
      newg.addVertex(newPosition); // doing this here and not in next block because adding edges requires all nodes to be present beforehand
    }

    // connect new nodes in new graph using the edges from the old graph
    for (Map.Entry<PVector, PVector> entry : oldNewPositions.entrySet()) {
      PVector oldPoint = entry.getKey();
      PVector newPoint = entry.getValue();

      // connect the new positions to the correct new positioned neighbor vertices using the oldnewpositions map
      for (DefaultEdge e : g.edgesOf(oldPoint)) {
        PVector opposite = Graphs.getOppositeVertex(g, e, oldPoint);
        PVector oppositeNew = oldNewPositions.get(opposite);
        newg.addEdge(newPoint, oppositeNew);
      }
    }

    // replace the exisiting graph with the newly calculated one
    g = newg;
    if (drawHamiltonian) {
      hamiltonianPath();
    };
  }

  void generateEdge() {
    intersectMap = new TreeMap<PVector, DefaultEdge>(
      new Comparator<PVector>() {

      @Override
        public int compare(PVector o1, PVector o2) {
        if (o1.x < o2.x) return -1;
        if (o1.x > o2.x) return 1;
        return 0;
      }
    }
    );
    c = generateCandidate();
    // make map with intersect point and which edge it belongs to
    for (DefaultEdge e : g.edgeSet()) {
      PVector p1 = g.getEdgeSource(e);
      PVector p2 = g.getEdgeTarget(e);
      PVector intersect = lineLine(new PVector[]{p1, p2}, c);
      if (intersect != null) {
        intersectMap.put(intersect, e);
      }
    }

    // need at least 2 intersects to continue
    if (intersectMap.size() < 2) return;

    // get two random neigboring points
    Random generator = new Random();
    Object[] values = intersectMap.keySet().toArray();
    int r = generator.nextInt(values.length - 1);
    PVector i1 = (PVector) values[r];
    PVector i2 = (PVector) values[r+1];
    g.addVertex(i1);
    g.addVertex(i2);
    g.addEdge(i1, i2);

    // split the two edges on their intersecting points:
    // remove the edge and connect intersect with both the source and target
    DefaultEdge e1 = intersectMap.get(i1);
    DefaultEdge e2 = intersectMap.get(i2);
    g.removeEdge(e1);
    g.removeEdge(e2);

    PVector p1 = g.getEdgeSource(e1);
    PVector p2 = g.getEdgeTarget(e1);
    g.addEdge(p1, i1);
    g.addEdge(p2, i1);

    p1 = g.getEdgeSource(e2);
    p2 = g.getEdgeTarget(e2);
    g.addEdge(p1, i2);
    g.addEdge(p2, i2);

    if (drawHamiltonian) {
      hamiltonianPath();
    };
  }

  //TODO: maybe don't allow vertical lines bc sorting on x values
  PVector[] generateCandidate() {
    // straight line through the middle, random angle, then offset perpendicular
    float angle = random(TWO_PI);
    // make vector (from origin) with random angle, r left out of formula bc setting it with setMag()
    PVector p = PVector.fromAngle(angle);
    /// set it s length, long enough
    p.setMag(width + height);
    // translate it so its opposite goes through the middle
    p.add(new PVector(width, height));
    // get its opposite and translate so line goes through the middle
    PVector op = p.copy().mult(-1).add(new PVector(width, height));
    
    // move random perpendicular
    // get counterclockwise right angle
    float rAngle = p.heading() - PI/2;
    // perpendicular PVector u translate by
    PVector perp = PVector.fromAngle(rAngle);
    float perpOffset = random(0, (width+height)/4);
    perp.setMag(perpOffset);
    p.add(perp);
    op.add(perp);
    
    PVector[] candidate = {p, op};
    return candidate;
    
    //Random r = new Random();
    //boolean hor = r.nextBoolean();
    //PVector p1 = new PVector(0, 0);
    //PVector p2 = new PVector(0, 0);
    //if (hor) {
    //  p1 = new PVector(random(-width, width), -10);
    //  p2 = new PVector(random(-width, width), random(height, height+10));
    //} else {
    //  p1 = new PVector(-10, random(-height, height));
    //  p2 = new PVector(width+10, random(-height, height));
    //}

    //PVector[] candidate = {p1, p2};
    //return candidate;
  }

  DefaultUndirectedGraph generateGraph() {
    g = new DefaultUndirectedGraph<PVector, DefaultEdge>(DefaultEdge.class);

    PVector p1 = new PVector(100, 100);
    PVector p2 = new PVector(width-100, 100);
    PVector p3 = new PVector(width-100, height-100);
    PVector p4 = new PVector(100, height-100);

    g.addVertex(p1);
    g.addVertex(p2);
    g.addVertex(p3);
    g.addVertex(p4);

    g.addEdge(p1, p2);
    g.addEdge(p2, p3);
    g.addEdge(p3, p4);
    g.addEdge(p4, p1);

    startingNodes.add(p1);
    startingNodes.add(p2);
    startingNodes.add(p3);
    startingNodes.add(p4);

    return g;
  }

  // www.jeffreythompson.org/collision-detection/line-line.php
  PVector lineLine(PVector[] e1, PVector[] e2) {

    float x1 = e1[0].x;
    float y1 = e1[0].y;
    float x2 = e1[1].x;
    float y2 = e1[1].y;
    float x3 = e2[0].x;
    float y3 = e2[0].y;
    float x4 = e2[1].x;
    float y4 = e2[1].y;
    // calculate the distance to intersection point
    float uA = ((x4-x3)*(y1-y3) - (y4-y3)*(x1-x3)) / ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1));
    float uB = ((x2-x1)*(y1-y3) - (y2-y1)*(x1-x3)) / ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1));

    // if uA and uB are between 0-1, lines are colliding
    if (uA >= 0 && uA <= 1 && uB >= 0 && uB <= 1) {

      // optionally, draw a circle where the lines meet
      float intersectionX = x1 + (uA * (x2-x1));
      float intersectionY = y1 + (uA * (y2-y1));
      fill(255, 0, 0);
      ellipse(intersectionX, intersectionY, 20, 20);

      return new PVector(intersectionX, intersectionY);
    }
    return null;
  }
}
