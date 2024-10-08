# Gossip and Push-Sum Algorithm Execution

### Authors
1. **Sashank Boppana, 4171-9973**
2. **Tejesh Boppana, 1234-0626**

### About the Project
This project implements a simulator for Gossip-type algorithms using the Pony programming language. It focuses on two specific algorithms: 
1.  **Gossip algorithm for information propagation**
2.  **Push-Sum algorithm for distributed sum computation**

### Project Overview
The simulator is designed to study the convergence of Gossip and Push-Sum algorithms in various network topologies. It uses an actor-based model to represent nodes in the network, leveraging Pony's built-in actor system for concurrent and asynchronous execution.

### Key Features
1. Multiple Algorithms: Supports both Gossip and Push-Sum algorithms.
2. Various Network Topologies: Implements full network, line, 3D grid, and imperfect 3D grid topologies.
3. Configurable Parameters: Allows setting the number of nodes, topology, and algorithm via command-line arguments.
4. Convergence Detection: Tracks and reports the convergence of nodes in the network.
5. Performance Measurement: Measures and reports the time taken for the network to converge. It also reports the percentage of CPU used for the provided inputs.

### Algorithms
1. **Gossip Algorithm**
Propagates information (rumor) through the network.
Each actor selects a random neighbor to spread the rumor.
Convergence is achieved when an actor has heard the rumor 10 times.
2. **Push-Sum Algorithm**
Computes the average of values distributed across the network.

### Largest network I managed to solve
Algorithm: Gossip
1. Topology: Full, Network size = 13000
2. Topology: Line, Network size = 6000
3. Topology: 3D, Network size = 300000
4. Topology: imp3D, Network size = 200000

Algorithm: Push-sum
1. Topology: Full, Network size = 15500
2. Topology: Line, Network size = 800
3. Topology: 3D, Network size = 50000
4. Topology: imp3D, Network size = 200000

### Network Topologies
1. **Full Network:** Every actor is connected to every other actor.
2. **3D Grid:** Actors are arranged in a three-dimensional grid.
3. **Line:** Actors are arranged in a linear fashion.
4. **Imperfect 3D Grid:** A 3D grid with additional random connections.

### Usage
To run the simulator, use the following command:
```bash
time ./Gossip-Algorithm-main <numNodes> <topology> <algorithm>
```

Where:
numNodes: Number of actors in the network
topology: One of "full", "3D", "line", or "imp3D"
algorithm: Either "gossip" or "pushsum"

### Implementation Details
Written in Pony programming language.
Uses Pony's actor model for concurrent execution.
Implements custom timer and timeout mechanisms.
Provides detailed debug output for analysis.
This project serves as a tool for studying the behavior and performance of Gossip-type algorithms in different network configurations, offering insights into their convergence properties and efficiency in various topologies.