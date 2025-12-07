# Library

This library contains a collection of models completely open and developed in mixed way by simscape code, C code, matlab code and simulink. All blocks are 
saved as **library** and masked, to be usable by other repositories like **solid state transformers** and **modelization and control**.

This repository contains the followind data.

# Documentation
**documentsation**.
- This folder contains the following documentations.
  - **advanced control engineering**: collections of problems and model derivations with some pages on theory derivation;
  - **electrification of heavy duty**: an approach to mapping an hydrostatic power train into an electrical powertrain;
  - **litium-ion battery**: model derivation;
  - **nonlinear observer**: apporach to hydristatic drivetrain using Khalil apporach;
  - **pmsm motor model and control**: $\alpha-\beta$ and $dq$ derivation and representation of the three phase permanent magnet synchronous machine and model predictive control; 
  - **induction motor model and control**: $\alpha-\beta$ and $dq$ derivation and representation of the three phase induction motor and controls; 
  - **pem fuel cell**: model of the proton-exchange membrane fuel cell;
  - **three phase inductors**: simscape modelization of a three phase inductance;
  - **solid state transformers**: performance analysis using different HW architecture and control system;
        - **single phase DAB versus single phase LLC**
        - **single phase DAB versus three phase DAB**
        - **single phase full bridge versus single phase NPC full bridge**
        - **single phase full bridge versus single phase TNPC full bridge**
        - **SiC versus Si based semiconductor devices**

# Fundamental SSC models
**foundation**:
- collection of simscape models built in ssc;

# User masked models
**masked models**:
- collection of simulunk block with masked interface, as follows
	- controllers: masked block with pi(), vector_pi(), ... and so on;
	- dclinks: masked dclink block with and without center tap;
	- electrical machines: PSM, IM, and transformers models designed in simscape; 
	- electronic components: custom opamp based on LT1210;
	- filters: different filters for LP, BP MAVG, written in matlab code and ccaller; 
	- lithium ion battery: in simscape with Kalman SOC estimator;
	- loads: user defined loads;
	- metering: block which implements a power measurement according to VDE4111 or IEC;
	- modulators: a collection of PWM based modulator with also space vector for: 3L three phase inverter, 2L three phase inverter, 3L single phase inverter, 2L single phase inverter, DAB, LLC, three phase DAB;   
	- power supply emulators: masked power supply emulator;
	- semiconductors: models for semiconductor devices (under construction);
	
# User CCallers
**user_defined_functions**:
- collection of ccaller functions written in C;

# User settings
**setup_files**:
- collection global setting and global data;