# ILS - Image Labeling System
To run: <br />
1. Open a MATLAB terminal for the local server. <br />
2. Open a MATLAB terminal for each remote agent. <br />
3. Initialize experiment environment by creating an environment: <br />
  "E = Experiment(data,labels);" <br />
4. Select "Start Scan" button from GUI. <br />
5. Initialize agents in each MATLAB terminal. <br />
  For Human agents: "H = Human(port,imageDatabasePath);" <br />
  For Computer-Vision agents: "CV = ComputerVision(port,imageDatabasePath);" <br />
6. Select "Stop Scan" button from GUI. <br />
7. Make selections for assignment type and fusion type on GUI. <br />
8. Begin experiment by selecting the start button on the GUI. <br />

## Dependencies
This code has been written using Matlab 2015a and later and has not been tested using earlier versions. In order to use, you must have access to Matlab's image processing toolbox, optimization toolbox, and instrument control toolbox. 

This code additionally requires the MatConvNet and LibSVM software packages.

MatConvNet is a deep-learning framework for matlab. It can be downloaded and installed from the [MatConvNet webpage](http://www.vlfeat.org/matconvnet/install/) and requires Matlab's parallel processing toolbox for gpu.

LibSVM is a support vector machine library that contains mexfiles for building SVMs in matlab. LibSVM can be downloaded from the [LibSVM webpage](https://www.csie.ntu.edu.tw/~cjlin/libsvm/).



