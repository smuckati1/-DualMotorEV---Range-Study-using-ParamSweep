function [neuralODE,airflowerror,torqueerror,maperror,egterror]=FitSiEngineDL(varargin)

% Function fits a Deep Learning model to measured data or data from SiDynamometer
%
%
% Copyright 2016-2022 The MathWorks, Inc.

%Check available licenses
if ~(dig.isProductInstalled('Deep Learning Toolbox')&&dig.isProductInstalled('Statistics and Machine Learning Toolbox')&&license('test','neural_network_toolbox')&&license('test','statistics_toolbox'))               
    errordlg('Statistics and Machine Learning Toolbox and Deep Learning Toolbox install and license are required for Deep Learning Engine Model Generation','Toolbox Support')
end

ModelName=[]; %Default to external data reference

try
    UseGTPlant=evalin('base','UseGTPlant');
catch
    UseGTPlant=false;
end

VVmode=false; %Default to non Virtual-Vehicle mode


%Set emphasis on steady-state fit quality (1=twice the emphasis on
%steady-state than transient, 2=triple the emphasis on steady-state than
%transient

SteadyStateLossMult=1;

options=struct;

%Pre-processing options
options.dataPreProcessingOptions.smoothData=true;
options.dataPreProcessingOptions.smoothingWindowSize=10;
options.dataPreProcessingOptions.downsampleData=true;
options.dataPreProcessingOptions.downsampleRatio=10;
options.dataPreProcessingOptions.standardizeData=true;
options.dataPreProcessingOptions.addDithering=false;
options.dataPreProcessingOptions.ditheringNoiseLevel=0.001;

options.useAugmentation=true;
options.augmentationSize=5;

% options for the NARX-like model
options.useTappedDelay=false;
options.inputDelays=1:4;
options.outputDelays=[];

% Optimizer options
options.initialLearnRate=0.01;
options.learnRateDropFactor=0.99;
options.learnRateDropPeriod=1;

%Gradient options
options.l2Regularization = 0.0001;
options.gradientThresholdMethod = "global-l2norm";% mustBeMember(gradientThresholdMethod,["global-l2norm","absolute-value"])
options.gradientThreshold = 2;

% Specify training epochs and mini batch size
options.miniBatchSize=128;
options.maxEpochs=80;

% time limit for training
options.timeLimit=12*3600; % seconds

% create and initialize deep learning network
options.hiddenUnits=100;
options.numFullyConnectedLayers=3;
options.actfunName="sigmoid";

fparent='';
if nargin==1 %User provides model from which to gather data

    ModelName=varargin{1};

    wbhandle=waitbar(0,'Generating Design of Experiments...');

    [EngInputs,EngOutputs,Ts]=ExecuteDoE(ModelName,UseGTPlant,SteadyStateLossMult);

    if UseGTPlant
        save GTDoEData EngInputs EngOutputs Ts
    end

    % options related to ODE integration
    options.Ts=Ts;

elseif nargin==2 %User provides model from which to gather data and max training epochs

    ModelName=varargin{1};

    wbhandle=waitbar(0,'Generating Design of Experiments...');

    [EngInputs,EngOutputs,Ts]=ExecuteDoE(ModelName,UseGTPlant,SteadyStateLossMult);

    options.maxEpochs=varargin{2};

    options.Ts=Ts;

elseif (nargin==4)&&isnumeric(varargin{4}) %User provides data directly using default options

    wbhandle=waitbar(0,'Setting Up Deep Learning Training...');

    EngInputs=varargin{1};
    EngOutputs=varargin{2};
    Ts=varargin{3};

    options.maxEpochs=varargin{4};
    options.Ts=Ts;

elseif (nargin==4)&&isstruct(varargin{4}) %User provides data directly using supplied options

    wbhandle=waitbar(0,'Setting Up Deep Learning Training...');

    EngInputs=varargin{1};
    EngOutputs=varargin{2};
    Ts=varargin{3};
    options=varargin{4};
    options.Ts=Ts;

elseif (nargin==5)&&isnumeric(varargin{1})&&isnumeric(varargin{2})&&isnumeric(varargin{3})&&isnumeric(varargin{4})&&isnumeric(varargin{5}) %Virtual Vehicle use-case

    EngInputs=varargin{1};
    EngOutputs=varargin{2};
    Ts=varargin{3};
    options.maxEpochs=varargin{4};
    options.dataPreProcessingOptions.downsampleRatio=varargin{5};

    options.Ts=Ts;
    options.dataPreProcessingOptions.downsampleData=true;

    VVmode=true;

elseif (nargin==6)&&isnumeric(varargin{1})&&isnumeric(varargin{2})&&isnumeric(varargin{3})&&isnumeric(varargin{4})&&isnumeric(varargin{5}) %Virtual Vehicle use-case
    EngInputs=varargin{1};
    EngOutputs=varargin{2};
    Ts=varargin{3};
    options.maxEpochs=varargin{4};
    options.dataPreProcessingOptions.downsampleRatio=varargin{5};
    options.Ts=Ts;
    options.dataPreProcessingOptions.downsampleData=true;
    VVmode=true;
    fparent=varargin{6};
else
    error(getString(message('autoblks:autoblkErrorMsg:errInvNInp')));  %RLR
end

if ~VVmode
    waitbar(0.25,wbhandle,'Training deep learning model...');
end

if ~isempty(fparent)
    neuralODE=autoblkssidlfit(EngInputs,EngOutputs,options,fparent{1});
else
    neuralODE=autoblkssidlfit(EngInputs,EngOutputs,options);
end


%Set engine shutdown initial condition definition
neuralODE.data.Y0=([0. 0. 101325. 293.15]'-neuralODE.data.muY')./neuralODE.data.sigY';

if UseGTPlant
    save GTDoEDataNNFit neuralODE
end

if ~VVmode
    waitbar(0.75,wbhandle,'Training is complete...')
end


%Plot DoE
PlotDoE(EngInputs);

%Plot Validation
[~,~,~,airflowerror,torqueerror,maperror,egterror]=ValidateODENN(EngInputs,EngOutputs,Ts,neuralODE,options,fparent);

%Set up calibration parameters of DL model for export to Simulink
neuralODETmp=neuralODE; %Store neuralODE structure containing dlmodel
neuralODE=rmfield(neuralODE,'dlmodel');  %Temporarily remove dlmodel NN object from Simulink export


%Get SI Core Engine physical parameters shared with DL engine model
if ~VVmode

    waitbar(0.9,wbhandle,'Performance-testing Deep Learning engine model...')
    DLModelName='SiDLEngine';
    load_system(DLModelName);
    SiCoreEngineModelName='SiEngineCore';
    load_system(SiCoreEngineModelName);
    SiEngineModelName='SiEngine';
    load_system(SiEngineModelName);
    hwsp=get_param(SiEngineModelName,'modelworkspace');
    hwspc=get_param(SiCoreEngineModelName,'modelworkspace');
    hwsdl=get_param(DLModelName,'modelworkspace');

    %Common SI Engine and DL Engine model physical plant parameters
    assignin(hwsdl,'AccPwrTbl',getVariable(hwsp,'AccPwrTbl'));
    assignin(hwsdl,'AccSpdBpts',getVariable(hwsp,'AccSpdBpts'));
    assignin(hwsdl,'TimeCnstICP',getVariable(hwsp,'TimeCnstICP'));
    assignin(hwsdl,'TimeCnstECP',getVariable(hwsp,'TimeCnstECP'));
    assignin(hwsdl,'TimeCnstWGA',getVariable(hwsp,'TimeCnstWGA'));
    assignin(hwsdl,'TimeCnstETC',getVariable(hwsp,'TimeCnstETC'));

    %Common SI Engine Core and DL Engine model physical plant parameters
    assignin(hwsdl,'NCyl',getVariable(hwspc,'NCyl'));
    assignin(hwsdl,'Vd',getVariable(hwspc,'Vd'));
    assignin(hwsdl,'Lhv',getVariable(hwspc,'LHV'));
    assignin(hwsdl,'Cps',getVariable(hwspc,'Cps'));
    assignin(hwsdl,'Pstd',getVariable(hwspc,'Pstd'));
    assignin(hwsdl,'Tstd',getVariable(hwspc,'Tstd'));
    assignin(hwsdl,'Rair',getVariable(hwspc,'Rair'));
    assignin(hwsdl,'cp_air',getVariable(hwspc,'cp_air'));
    assignin(hwsdl,'f_sa_opt',getVariable(hwspc,'f_sa_opt'));
    assignin(hwsdl,'f_tq_inr_l_bpt',getVariable(hwspc,'f_tq_inr_l_bpt'));
    assignin(hwsdl,'f_tq_inr_n_bpt',getVariable(hwspc,'f_tq_inr_n_bpt'));
    assignin(hwsdl,'Sinj',getVariable(hwspc,'Sinj'));
    assignin(hwsdl,'afr_stoich',getVariable(hwspc,'afr_stoich'));

    DLModelParmNames={'neuralODE'};

    for i=1:length(DLModelParmNames)
        assignin(hwsdl,DLModelParmNames{i},eval(DLModelParmNames{i}));
    end

    %Restore dlmodel object to neuralODE structure in case user wants to use
    %it later
    neuralODE=neuralODETmp;

    %Save DL model with new parameters
    save_system(DLModelName,'SaveModelWorkspace',true,'OverwriteIfChangedOnDisk',true);
    close_system(DLModelName,0);

    Simulink.data.dictionary.closeAll; %close Simulink data dictionaries after assigns

    %Execute engine mapping experiment on Deep Learning Engine Model
    if ~isempty(ModelName)&&~(nargin==2)
        set_param([ModelName '/Engine System/Engine Plant/Engine'],'LabelModeActiveChoice','SiDLEngine');
        DynamometerStart([ModelName '/Subsystem1'],'SteadyState');
    end

    close(wbhandle);
end

end


function [EngInputs,EngOutputs,Ts]=ExecuteDoE(ModelName,UseGTPlant,SteadyStateLossMult)

% Generate engine test data via DoE for training and test set
OpenLoopMaxMAP=2.25e5;

Ts=0.01;

NumPoints=250;
lb=[500 0 0 99 0 -10 0.7];
ub=[1500 5 100 50 50 0 1];
v1=GenDoE(NumPoints,lb,ub);

NumPoints=500;
lb=[500 0 0 0 0 -10 0.7];
ub=[6500 100 100 50 50 0 1];
v2=GenDoE(NumPoints,lb,ub);

NumPoints=250;
lb=[500 0 0 99 0 -10 0.7];
ub=[1500 5 100 50 50 0 1];
v3=GenDoE(NumPoints,lb,ub);

NumPoints=500;
lb=[500 0 0 0 0 -10 0.7];
ub=[6500 100 100 50 50 0 1];
v4=GenDoE(NumPoints,lb,ub);

v=[v1;v2;v3;v4];

% construct the engine input vectors

SteadyEngSpdCmdPts=v(:,1)';
SteadyTpCmdPts=v(:,2)';
SteadyWAPCmdPts=v(:,3)';
SteadyIntCamPhsCmdPts=v(:,4)';
SteadyExhCamPhsCmdPts=v(:,5)';
SteadySpkDeltaCmdPts=v(:,6)';
SteadyLambdaCmdPts=v(:,7)';

hmws=get_param(ModelName,'modelworkspace');

%Store new test points in model
assignin(hmws,'OpenLoopEngSpdCmdPts',SteadyEngSpdCmdPts);
assignin(hmws,'OpenLoopTpCmdPts',SteadyTpCmdPts);
assignin(hmws,'OpenLoopWAPCmdPts',SteadyWAPCmdPts);
assignin(hmws,'OpenLoopIntCamPhsCmdPts',SteadyIntCamPhsCmdPts);
assignin(hmws,'OpenLoopExhCamPhsCmdPts',SteadyExhCamPhsCmdPts);
assignin(hmws,'OpenLoopSpkDeltaCmdPts',SteadySpkDeltaCmdPts);
assignin(hmws,'OpenLoopLambdaCmdPts',SteadyLambdaCmdPts);
assignin(hmws,'OpenLoopMaxMAP',OpenLoopMaxMAP);

DynoCtrlBlk=[ModelName,'/Dynamometer Control'];
set_param(DynoCtrlBlk,'OverrideUsingVariant','OpenLoop');

OrigStopTime=get_param(ModelName,'StopTime');

set_param(ModelName,'StopTime','300000');

StopFcn=get_param([ModelName '/Performance Monitor'],'StopFcn');
set_param([ModelName '/Performance Monitor'],'StopFcn','');

%Set up logging
Block=[ModelName '/Performance Monitor/Dynamic Logging/LogData'];
ph=get_param(Block,'porthandles');
lh=get_param(ph.Outport,'Line');
set_param(lh,'Name','DynMeasurements');
set_param(ph.Outport,'DataLogging','on');
set_param(ph.Outport,'DataLoggingSampleTime',num2str(Ts));

%Turn on signal logging for throttle upstream pressure
if ~UseGTPlant
    load_system('SiEngineCore');
    ThrottleBlockName='SiEngineCore/Throttle Body/Flow Orifice Reformatted/Compressible Flow Orifice/Pressure FlowAdjust ';
    Porthandles=get_param(ThrottleBlockName,'Porthandles');
    Outporthandles=Porthandles.Outport;
    set_param(Outporthandles(2),'DataLogging','on');
    save_system('SiEngineCore','OverwriteIfChangedOnDisk',true);
    close_system('SiEngineCore',0);
else
    ThrottleBlockName=[ModelName '/Engine System/Engine Plant/Engine/SiEngine/GT Turbo 1.5L SI DIVCP Engine Model/Gain8'];
    Porthandles=get_param(ThrottleBlockName,'Porthandles');
    Outporthandles=Porthandles.Outport;
    set_param(Outporthandles(1),'DataLogging','on');
end

%Turn on signal logging for lambda command
LambdaCommandBlockName=[ModelName '/Dynamometer Control/Open Loop/LambdaCmd Filter'];
Porthandles=get_param(LambdaCommandBlockName,'Porthandles');
Outporthandles=Porthandles.Outport;
set_param(Outporthandles(1),'DataLogging','on');

%Turn on signal logging for commanded spark delta command
SpkDeltaCommandBlockName=[ModelName '/Dynamometer Control/Open Loop/SpkDeltaCmd Filter'];
Porthandles=get_param(SpkDeltaCommandBlockName,'Porthandles');
Outporthandles=Porthandles.Outport;
set_param(Outporthandles(1),'DataLogging','on');

%Turn on signal logging for wastegate boost limit learning mode
WAPLearnBlockName=[ModelName '/Dynamometer Control/Open Loop/Select Operating Point'];
Porthandles=get_param(WAPLearnBlockName,'Porthandles');
Outporthandles=Porthandles.Outport;
set_param(Outporthandles(11),'DataLogging','on');

%Set up parameters needed for Open Loop controller
ControllerModelName='SiEngineController';
load_system(ControllerModelName);
hwsc=get_param(ControllerModelName,'modelworkspace');
hwstm=get_param(ModelName,'modelworkspace');
assignin(hwstm,'Cps',getVariable(hwsc,'Cps'));
assignin(hwstm,'NCyl',getVariable(hwsc,'NCyl'));
assignin(hwstm,'Sinj',getVariable(hwsc,'Sinj'));
assignin(hwstm,'afr_stoich',getVariable(hwsc,'afr_stoich'));
assignin(hwstm,'Nmin',1);

%Run the DoE test
out=sim(ModelName,'SignalLogging','on','SignalLoggingName','logsout');

%Find throttle upstream pressure measurement

if ~UseGTPlant
    logsoutindex=NaN;

    for i=1:out.logsout.numElements
        BlockPath=out.logsout{i}.BlockPath;
        BlockPath=BlockPath.convertToCell;
        if strcmp(ThrottleBlockName,BlockPath{end})
            logsoutindex=i;
            break;
        end
    end

    ThrottleUpstreamPressure=out.logsout{logsoutindex}.Values;
else
    ThrottleUpstreamPressure=out.logsout.get('ThrottleUpstreamPressure');
    ThrottleUpstreamPressure=ThrottleUpstreamPressure.Values;
end

%Find Lambda input measurement
LambdaCmd=out.logsout.get('LambdaCmd');
LambdaCmd=LambdaCmd.Values;

%Find Spark Delta input measurement
SpkDeltaCmd=out.logsout.get('SpkDeltaCmd');
SpkDeltaCmd=SpkDeltaCmd.Values;

%Find wastegate learn state
WAPLearn=out.logsout.get('WAPLearn');
WAPLearn=WAPLearn.Values;


%clean up figures
h=findall(0, 'Type', 'figure', 'Tag', 'DynamometerWaitbarFig');
if ~isempty(h)
    delete(h(1))
end

h=findall(0, 'Type', 'figure', 'Tag', 'RebuildModelWaitbarFig');
if ~isempty(h)
    delete(h(1))
end

%Restore Performance Monitor StopFcn
set_param([ModelName '/Performance Monitor'],'StopFcn',StopFcn);

%Restore original stop time
set_param(ModelName,'StopTime',OrigStopTime);

%Form input and output arrays
EngInputNames={'Engine speed (rpm)','Throttle position percent','Wastegate area percent','Injection pulse width (ms)','Spark advance (degCrkAdv)','Intake cam phase command (degCrkAdv)','Exhaust cam phase command (degCrkRet)','Torque command (N*m)'};
EngInputNames=strrep(strrep(strrep(strrep(strrep(EngInputNames,' ','_'),')','_'),'(','_'),'*','_'),'/','_');

EngOutputNames={'Measured engine torque (N*m)','Intake manifold pressure (kPa)','Fuel mass flow rate (g/s)','Exhaust manifold temperature (C)','Turbocharger shaft speed (rpm)','Intake port mass flow rate (g/s)','Intake manifold temperature (C)','Tailpipe HC emissions (g/s)','Tailpipe CO emissions (g/s)','Tailpipe NOx emissions (g/s)','Tailpipe CO2 emissions (g/s)'};
EngOutputNames=strrep(strrep(strrep(strrep(strrep(EngOutputNames,' ','_'),')','_'),'(','_'),'*','_'),'/','_');

EngOutputConversionSlopes=[1 1000 0.001 1 1 0.001 1 0.001 0.001 0.001 0.001];
EngOutputConversionOffsets=[0 0 0 273.15 0 0 273.15 0 0 0 0];

Measurement=out.logsout.find('DynMeasurements');
time=Measurement.Values.Time__s_.Time;

for i=1:length(EngInputNames)
    EngInputs(:,i)=eval(['Measurement.Values.' EngInputNames{i} '.Data']);
end

for i=1:length(EngOutputNames)
    EngOutputs(:,i)=eval(['Measurement.Values.' EngOutputNames{i} '.Data'])*EngOutputConversionSlopes(i)+EngOutputConversionOffsets(i);
end

%Add spark delta and lambda command inputs to the end
EngInputs(:,end+1)=interp1(SpkDeltaCmd.Time,SpkDeltaCmd.Data,time);
EngInputs(:,end+1)=interp1(LambdaCmd.Time,LambdaCmd.Data,time);


%Add throttle upstream pressure at the end
EngOutputs(:,end+1)=interp1(ThrottleUpstreamPressure.Time,ThrottleUpstreamPressure.Data,time);

%Add wastegate learn state at the end
EngOutputs(:,end+1)=(interp1(WAPLearn.Time,double(WAPLearn.Data),time)>0.5);

%Add weights at end
WAPLearn=EngOutputs(:,13);

w=zeros(size(WAPLearn));

for i=2:size(WAPLearn,1)

    w(i,1)=0;

    if WAPLearn(i)<WAPLearn(i-1)
        startind=i;
    end

    if WAPLearn(i)>WAPLearn(i-1)
        endind=i-1;
        w(startind:endind,1)=1+SteadyStateLossMult*((startind:endind)-startind)/(endind-startind)';
    end

end

EngOutputs(:,end+1)=w;

%Remove data where wastegate learning for boost limits is being conducted
EngOutputs=EngOutputs(WAPLearn<0.5,:);
EngInputs=EngInputs(WAPLearn<0.5,:);

Simulink.data.dictionary.closeAll;  %close .sldd files for long runs

end


function v=GenDoE(NumPoints,lb,ub)

p=sobolset(size(lb,2));
DOE.Type='sobol';

%scramble points (randomize it)
p=scramble(p,'MatousekAffineOwen');

m=net(p,NumPoints); %Extract quasi-random point set

r=ub-lb;
meanval=(ub+lb)/2.;

% scale sobolset values to physical values
v=zeros(size(m));
for k=1:size(m,2)
    v(:,k)=(m(:,k)-0.5)*r(k)+meanval(k);
end

% put zone center inputs in middle of test
v=[v(1:NumPoints/2,:);meanval;meanval;v(NumPoints/2+1:end,:)];

end


%DoE plots
function PlotDoE(EngInputs)

Speed=EngInputs(:,1);
Throttle=EngInputs(:,2);
Wastegate=EngInputs(:,3);
IntakeCam=EngInputs(:,6);
ExhaustCam=EngInputs(:,7);
SparkDelta=EngInputs(:,9);
Lambda=EngInputs(:,10);

Type=true(size(Speed)); %Set train = true
Type((round(size(Type,1)/2)+1):end)=false; %Set test = false

Inputs=[Speed Throttle Wastegate IntakeCam ExhaustCam SparkDelta Lambda];

TrainInputs=Inputs(1:round(size(Inputs,1)/2),:);
TrainType=Type(1:round(size(Type,1)/2),:);

TestInputs=Inputs((round(size(Type,1)/2)+1):end,:);
TestType=Type((round(size(Type,1)/2)+1):end,:);

X=[TrainInputs;TestInputs];
Type=[TrainType;TestType];

color=lines(2);
xnames = {'Speed','Throttle','Wastegate','IntakeCam','ExhaustCam','SparkDelta','Lambda'};
group = categorical(Type,[true false],{'Train','Test'});
% if ~isempty(fparent)
%     p=uipanel(fparent{2},...
%         'AutoResizeChildren','off');
%     [H,AX,BigAx] = gplotmatrix(p,X,[],group,color,[],[],[],'variable',xnames,'o');
%     BigAx.Title.String='Overlay of Test vs Train Steady-State Input Targets';
%     set(p,'Position',[193.5714  108.4286  953.7143  698.8571]);
% else
h=figure;
set(h,'Name','Overlay of Test vs Train Steady-State Input Targets','NumberTitle','off', 'WindowStyle', 'Docked');
[~,~] = gplotmatrix(X,[],group,color,[],[],[],'variable',xnames,'o');
title('Overlay of Test vs Train Steady-State Input Targets');
%set(gcf,'Position',[193.5714  108.4286  953.7143  698.8571]);
%end


end


%Validation plots
function [usim,ysim,yhatsim,airflowerror,torqueerror,maperror,egterror]=ValidateODENN(EngInputs,EngOutputs,Ts,neuralODE,options,fparent)

muu=neuralODE.data.muU;
muy=neuralODE.data.muY;
sigu=neuralODE.data.sigU;
sigy=neuralODE.data.sigY;

Throttle=EngInputs(:,2);
Wastegate=EngInputs(:,3);
Speed=EngInputs(:,1);
IntCamPhs=EngInputs(:,6);
ExhCamPhs=EngInputs(:,7);
SpkDelta=EngInputs(:,9);
Lambda=EngInputs(:,10);

MAP=EngOutputs(:,2);
Airflow=EngOutputs(:,6);
Torque=EngOutputs(:,1);
ThrottleInPrs=EngOutputs(:,12);
ExhTemp=EngOutputs(:,4);

u=[Throttle Wastegate Speed IntCamPhs ExhCamPhs SpkDelta Lambda];
x=[Airflow Torque MAP ExhTemp];

nrows=round(size(u,1)/2); %reduce resulting 100ms dataset by a factor of 2 - training will be done on the first 1/2th of the dataset
u=u(nrows+1:end,:);
x=x(nrows+1:end,:);

% output is same as states
y=x;

%Scale the training data
uscaled=(u-muu)./sigu;
yscaled=(y-muy)./sigy;

%Set up data for training
Uscaled=uscaled';
Yscaled=yscaled';

X=Yscaled;

T=Ts*((1:size(Uscaled,2))-1);

if options.useAugmentation

    X0=X(:,1);
    nx=size(X0,1);

    % augment states
    Xsim(:,1)=cat(1,X0,zeros(options.augmentationSize,1));

else

    Xsim(:,1)=X(:,1);

end

%ODE1 integration
for i=2:size(Uscaled,2)

    uin=Uscaled(:,i);
    xin=Xsim(:,i-1);
    dxdt=odeModel_fcn(uin,xin,neuralODE.model,neuralODE.trainingOptions.actfunName);
    Xsim(:,i)=xin+dxdt*Ts;

end

% Discard augmentation
if options.useAugmentation
    Xsim(nx+1:end,:)=[];
end

Ysim=Xsim;

Ysim=Ysim.*repmat(sigy',1,size(Ysim,2));

yhatsim=(Ysim+repmat(muy',1,size(Ysim,2)))';

ysim=y;
usim=u;
tsim=T;

h=figure;

set(h,'Name','Test Inputs 1-4','NumberTitle','off', 'WindowStyle', 'Docked');
ax(1)=subplot(4,1,1);
title('Engine Inputs and Outputs');
plot(tsim,usim(:,1));
grid on
ylabel('Throttle Position (%)');

ax(2)=subplot(4,1,2);
plot(tsim,usim(:,2));
grid on
ylabel('Wastegate Area (%)');

ax(3)=subplot(4,1,3);
plot(tsim,usim(:,3));
grid on
ylabel('Engine Speed (RPM)');

ax(4)=subplot(4,1,4);
plot(tsim,usim(:,4));
grid on
xlabel('Time (sec)');
ylabel('Intake Cam Phase (deg)');

linkaxes(ax(1:4),'x');

%set(gcf,'Position',[193.5714  108.4286  953.7143  698.8571]);


h=figure;
set(h,'Name','Test Inputs 5-7','NumberTitle','off', 'WindowStyle', 'Docked');
ax(5)=subplot(3,1,1);
plot(tsim,usim(:,5));
grid on
ylabel('Exhaust Cam Phase (deg)');

ax(6)=subplot(3,1,2);
plot(tsim,usim(:,6));
grid on
ylabel('Spark Delta (deg)');

ax(7)=subplot(3,1,3);
plot(tsim,usim(:,7));
grid on
ylabel('Lambda (-)');
xlabel('Time (sec)');

linkaxes(ax(5:7),'x');

%set(gcf,'Position',[193.5714  108.4286  953.7143  698.8571]);

h=figure;
set(h,'Name','Test Responses','NumberTitle','off', 'WindowStyle', 'Docked');
ax(8)=subplot(4,1,1);
plot(tsim,[ysim(:,1) yhatsim(:,1)]);
grid on
ylabel('Airflow (kg/s)');

ax(9)=subplot(4,1,2);
plot(tsim,[ysim(:,2) yhatsim(:,2)]);
grid on
ylabel('Torque (Nm)');

ax(10)=subplot(4,1,3);
plot(tsim,[ysim(:,3) yhatsim(:,3)]);
grid on
ylabel('Intake Manifold Pressure (Pa)');

ax(11)=subplot(4,1,4);
plot(tsim,[ysim(:,4) yhatsim(:,4)]);
grid on
ylabel('Exhaust Gas Temperature (K)');
xlabel('Time (sec)');

linkaxes(ax(8:11),'x');

%set(gcf,'Position',[193.5714  108.4286  953.7143  698.8571]);


%Plot error distribution for dynamic responses

h=figure;
set(h,'Name','Model Test Results','NumberTitle','off', 'WindowStyle', 'Docked');
subplot(2,2,1)
airflowerror=100*(yhatsim(:,1)-ysim(:,1))./ysim(:,1);
histogram(airflowerror,100,'BinLimits',[-20,20]);
grid on
xlabel('Airflow Error Under Dynamic Conditions (%)');
ylabel('Samples');

subplot(2,2,2)
torqueerror=100*(yhatsim(:,2)-ysim(:,2))./ysim(:,2);
histogram(torqueerror,100,'BinLimits',[-20,20]);
grid on
xlabel('Torque Error Under Dynamic Conditions (%)');
ylabel('Samples');

subplot(2,2,3)
maperror=100*(yhatsim(:,3)-ysim(:,3))./ysim(:,3);
histogram(maperror,100,'BinLimits',[-20,20]);
grid on
xlabel('Intake Manifold Pressure Error Under Dynamic Conditions (%)');
ylabel('Samples');

subplot(2,2,4)
egterror=100*(yhatsim(:,4)-ysim(:,4))./ysim(:,4);
histogram(egterror,100,'BinLimits',[-20,20]);
grid on
xlabel('Exhaust Gas Temperature Error Under Dynamic Conditions (K)');
ylabel('Samples');

%set(gcf,'Position',[193.5714  108.4286  953.7143  698.8571]);
%end
end


function y=odeModel_fcn(u,x,params,actFun)

% calculate outputs for each time point (y is a vector of values)
dxdt=[x;u];

% activation function
switch actFun
    case "tanh"
        actfun = @tanh;
    case "sigmoid"
        actfun = @sigmoid;
    otherwise
        error("Other functions will be added later")
end

% Forward calculation
tmp = cell(1,params.numFullyConnectedLayers-1);
% FullyConnectedLayer1 output
tmp{1} = actfun(params.("fc"+1).Weights*dxdt + params.("fc"+1).Bias);
% intermediate FullyConnectedLayer
for k = 2:params.numFullyConnectedLayers-1
    % FC layer output and activation function
    tmp{k} = actfun(params.("fc"+k).Weights*tmp{k-1} + params.("fc"+k).Bias);
end
% last FullyConnectedLayer output
y = params.("fc"+params.numFullyConnectedLayers).Weights*tmp{params.numFullyConnectedLayers-1} + params.("fc"+params.numFullyConnectedLayers).Bias;

end

function y = sigmoid(x)
y = 1./(1+exp(-x));
end