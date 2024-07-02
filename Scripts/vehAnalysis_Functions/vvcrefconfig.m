function [varargout]= vvcrefconfig(varargin)
%script for managing the reference generator block (no mask version)

%   Copyright 2022 The MathWorks, Inc.

% Disable OpenGL warning for parsim

warning('off','MATLAB:Figure:UnableToSetRendererToOpenGL');


block = varargin{1};
manType =varargin{2};

varargout{1} = {};
simStopped = autoblkschecksimstopped(block) && ~(strcmp(get_param(bdroot(block),'SimulationStatus'),'updating'));

vehSys = bdroot(block);
if length(varargin)>2
    sim3dEnabled =varargin{3};%strcmp(get_param(block,'engine3D'),'Enabled');
else
    sim3dEnabled = false;
end

switch manType
    case 'Double Lane Change'
        set_param([block '/Reference Generator'],'LabelModeActiveChoice','Double Lane Change');
        set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','1');
        set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','1');

        simTime = 25;
    case 'Increasing Steer'
        set_param([block '/Reference Generator'],'LabelModeActiveChoice','Increasing Steer');
        set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
        set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','0');


        simTime = 60;
    case 'Swept Sine'
        set_param([block '/Reference Generator'],'LabelModeActiveChoice','Swept Sine');
        set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
        set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','0');
        autoblksenableparameters(block, [], [],{'SSGroup'},{'ISGroup';'DLCGroup';'CRGroup';'SDGroup';'FHGroup';'DCGroup'});
        autoblksenableparameters(block,[],{'steerDir','t_start','xdot_r'},[],[],true);

        simTime = 40;
    case 'Sine with Dwell'
        set_param([block '/Reference Generator'],'LabelModeActiveChoice','Sine with Dwell');
        set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
        set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','0');


        simTime = 25;
    case 'Constant Radius'
        set_param([block '/Reference Generator'],'LabelModeActiveChoice','Constant Radius');
        set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','2');
        set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','1');


        simTime = 60;
    case 'Fishhook'
        set_param([block '/Reference Generator'],'LabelModeActiveChoice','Fishhook');
        set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
        set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','0');

        simTime = 40;
    case 'Drive Cycle'
        set_param([block '/Reference Generator'],'LabelModeActiveChoice','Drive Cycle');
        set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
        set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','2');

        if simStopped
            set_param([block,'/3D Engine'],'engine3D','Disabled');
        end
        loadedCycle = get_param([block '/Reference Generator/Drive Cycle/Drive Cycle Source'],'UserData');
        timeVec = loadedCycle.Time;
        simTime = timeVec(end);
    otherwise
end


% update driver sldd, and 3D initial positions
if simStopped
    update3DScene(block,manType);
    %[~] = vdynblksmdlWSconfig(block,false);
    dictionaryObj = Simulink.data.dictionary.open('VirtualVehicleTemplate.sldd');
    dDataSectObj = getSection(dictionaryObj,'Design Data');
    list=VirtualAssemblyScenarioParaList(manType);
    for i=1:length(list)
        ddObj = getEntry(dDataSectObj,list{i}{1});
        setValue(ddObj,str2double(list{i}{2}));
    end

    ddObj = getEntry(dDataSectObj,'ScnSimTime');
    setValue(ddObj,simTime);

    saveChanges(dictionaryObj);
end

end


function update3DScene(block,manType)
sim3DBlkPath = [block,'/3D Engine'];
if strcmp(manType,'Double Lane Change')
    set_param(sim3DBlkPath,'SceneDesc','Double lane change');
else
    set_param(sim3DBlkPath,'SceneDesc','Open surface');
end
end