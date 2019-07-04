clc;
clear;
close all;

%% functions (Cantera)
Air_prop = IdealGasMix('gri30.xml'); 
GetStates = @(Air_prop, mdot)[mdot,temperature(Air_prop),...
                        pressure(Air_prop),...
                        enthalpy_mass(Air_prop),...
                        entropy_mass(Air_prop),...
                        enthalpy_mass(Air_prop)*(mdot)];

%% Find indices of required species
i.nsp = nSpecies(Air_prop);
i.ch4    = speciesIndex(Air_prop,'CH4');
i.o2     = speciesIndex(Air_prop,'O2');
i.n2     = speciesIndex(Air_prop,'N2');
i.co2    = speciesIndex(Air_prop,'CO2');
i.h2o    = speciesIndex(Air_prop,'H2O');
i.co     = speciesIndex(Air_prop,'CO');
i.h2     = speciesIndex(Air_prop,'H2');
i.no     = speciesIndex(Air_prop,'NO');
i.no2    = speciesIndex(Air_prop,'NO2');

%% Input variables
I.Tam = 290;              % Ambient air temperature (K)
I.Pam = 101325;           % Ambient air pressure (Pa)
I.fdil = 0.4;             % Dilution air fraction (~)
I.nc = 0.86;              % Efficiency of compressor and turbine (~)
I.Qin = 1.46e+6;          % Heat energy added during combustion (KJ/kg)
I.EqRatio = 1;            % Equivalence ratio 0.4 to 0.9
I.LHV = 2.044e6;             % Fuel lower heating value (J/kg)
I.EqORCom = 1;            % Select 0 for complete or 1 for equilibrum
rp = 10;                  % pressure ratio (~)

%% Chemical setup
I.Fuel = zeros(i.nsp,1);
I.Fuel(i.ch4) = 1;
I.Air = zeros(i.nsp,1);
I.Air(i.o2) = 0.21;
I.Air(i.n2) = 0.79;

%% LOOP
for n = 1:26        % Number of Iterations for Varying Pressure Ratios 
    
mdot = 100;               % Mass flow rate of the air (kg/s)
% mdot1 = mdot*(1-I.fdil);  % Mass flow rate Split stream 2a
% mdot2 = mdot*(I.fdil);    % Mass flow rate Split stream 2b
    
%% State one 

set(Air_prop,'T',I.Tam,'P',I.Pam,'X',I.Air)    % Set Temerature and Pressure 

State(1,:) = GetStates(Air_prop,mdot);

%% State two s (isotropic)

set(Air_prop,'S',State(1,5),'P',I.Pam*rp) % Set entropy and Pressure 

State(2,:) = GetStates(Air_prop,mdot);

%% State two apply isotropic efficiency

ActH = ((State(2,4)-State(1,4))/(I.nc))+State(1,4);   % Actual enthalpy

set(Air_prop,'H',ActH,'P',I.Pam*rp)   % Set enthalpy and Pressure

State(3,:)=GetStates(Air_prop,mdot);
%% State two a

mdot = mdot*(1-I.fdil);         % Mass flow rate Split stream 2a
State(4,:)=GetStates(Air_prop,mdot);

%% State two b
mdot = (mdot/(1-I.fdil))-mdot;  % Mass flow rate Split stream 2b
State(5,:)=GetStates(Air_prop,mdot);

%% State two f (fuel)

set(Air_prop,'T',I.Tam,'P',I.Pam*rp,'X',I.Fuel)

% mdot = Stoichiometric(I,mdot);

State(6,:)=GetStates(Air_prop,mdot);

%% State three combustion ################# add fuel here ###########

mdot = mdot+State(4,1);

Combustion = (State(3,4))+((I.Qin));
I.FuelAirmix = I.Air;
set(Air_prop,'H',Combustion,'P',I.Pam*rp,'X',I.FuelAirmix)% Set enthalpy and Pressure

State(7,:)=GetStates(Air_prop,mdot);

%% State four mixing of two streams (dilution zone)
mdot = State(7,1)+State(5,1);

MixedStreams = (State(7,4)*(1-I.fdil))+(State(3,4)*I.fdil); 

set(Air_prop,'H',MixedStreams,'P',I.Pam*rp) % Set enthalpy and Pressure

State(8,:)=GetStates(Air_prop,mdot);

%% State five s Isentropic turbine expansion

set(Air_prop,'S',State(8,5),'P',I.Pam)      % Set entropy and Pressure

State(9,:)=GetStates(Air_prop,mdot);

%% State five Apply efficiency

ActH1 = (((State(8,4)-State(9,4))*-I.nc)+State(8,4));  % Actual enthalpy

set(Air_prop,'H',ActH1,'P',I.Pam)         % Set enthalpy and Pressure

State(10,:)=GetStates(Air_prop,mdot);

%% Work 

Work(1) = (State(1,4)-State(3,4));  % Compressor Work           Stage 1-3
Work(2) = (State(8,4)-State(3,4));  % Heat added to system      Stage 3-5
Work(3) = (State(8,4)-State(10,4)); % Turbine Work              Stage 5-7

EFF = (Work(3)+Work(1))/Work(2);    % Overall system efficiency
rps{n} =strcat('P',num2str(rp));    % Converts num to string for use in...
                                    % ... a struct file
S.(rps{n}) = State(:,:);  % Stores all States with varying pressure ratios

Output.EFFvsPR(n,1)  = rp;          % Stores the value of Pressure ratio
Output.EFFvsPR(n,2)  = EFF*100;     % Stores Effeincicy 
Output.TempvsPR(n,1) = rp;          % Stores the value of Pressure ratio
Output.TempvsPR(n,2) = State(8,2)-273.15; % Stores Temperature at state 4

rp = rp+2;      % Increases pressure ratio by 2 every iteration
end

% %% END LOOP , Start Admin section
% %% Graphs and Tables

Table_Pr40=array2table(S.P40,'VariableNames',{'Massflow_rate',...
    'Temperature','Pressure','Specific_Enthalpy','Specific_Entropy',...
    'Enthalpy'},'RowNames',...
    {'1','2s','2','2a','2b','2f','3','4','5s','5'})

figure(1)
plot(Output.EFFvsPR(:,1),Output.EFFvsPR(:,2),':*k')
title('Efficiency Vs Pressure ratio')
xlabel('Pressure Ratio')
ylabel('Effeniciey (%)')

figure(2)
plot(Output.EFFvsPR(:,1),Output.TempvsPR(:,2),':*k')
title('Temperature at state 4 Vs Pressure ratio')
xlabel('Pressure Ratio')
ylabel('Temperature (C)')
