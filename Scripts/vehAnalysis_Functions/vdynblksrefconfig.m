function [varargout]= vdynblksrefconfig(varargin)
%

%   Copyright 2018-2022 The MathWorks, Inc.

% Disable OpenGL warning for parsim

warning('off','MATLAB:Figure:UnableToSetRendererToOpenGL');

block = varargin{1};
maskMode = varargin{2};
varargout{1} = {};
simStopped = autoblkschecksimstopped(block) && ~(strcmp(get_param(bdroot(block),'SimulationStatus'),'updating'));
manType = get_param(block,'manType');
prevType = get_param(block,'prevType');
vehSys = bdroot(block);
manOverride = strcmp(get_param(block,'manOverride'),'on');
sim3dEnabled = strcmp(get_param(block,'engine3D'),'Enabled');
visPath = [vehSys '/Visualization'];
driverpath = [vehSys '/Driver Commands'];
visHandle = getSimulinkBlockHandle(visPath);
driverHandle = getSimulinkBlockHandle(driverpath);
if (driverHandle == -1) || (visHandle == -1)
    disp('Warning: The reference generator subsystem is intended to work only with the example project and model architecture that it ships in. Functionality may therefore be limited if used in another model where the visualization, driver or environment subsystems are no longer available or different locations.')
end
switch maskMode
    case 0
        [~]=vdynblksrefconfig(block,1);
        [~]=vdynblksrefconfig(block,3);
    case 1
        switch manType
            case 'Double Lane Change'
                set_param([block '/Reference Generator'],'LabelModeActiveChoice','Double Lane Change');
                if visHandle ~= -1
                    set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','1');
                    set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','1');
                else
                    disp('Warning: Visualization subsystem not found. Model scopes and visualizaiton aids may not function as expected.')
                end
                autoblksenableparameters(block, [], [],{'DLCGroup'},{'ISGroup';'CRGroup';'SSGroup';'SDGroup';'FHGroup';'DCGroup'});
                autoblksenableparameters(block,{'t_start','xdot_r'},{'steerDir'},[],[],true);
                if simStopped && manOverride  && ~strcmp(prevType,manType) && (driverHandle == -1) 
                    set_param([vehSys '/Driver Commands'],'driverType','Predictive Driver');
                end
                simTime = 25;
            case 'Increasing Steer'
                set_param([block '/Reference Generator'],'LabelModeActiveChoice','Increasing Steer');
                if visHandle ~= -1
                    set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
                    set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','0');
                else
                    disp('Warning: Visualization subsystem not found. Model scopes and visualizaiton aids may not function as expected.')
                end
                autoblksenableparameters(block, [], [],{'ISGroup'},{'DLCGroup';'CRGroup';'SSGroup';'SDGroup';'FHGroup';'DCGroup'});
                autoblksenableparameters(block,{'steerDir','t_start','xdot_r'},[],[],[],true);
                if simStopped && manOverride && ~strcmp(prevType,manType) && (driverHandle == -1) 
                    set_param([vehSys '/Driver Commands'],'driverType','Predictive Driver');
                end
                simTime = 60;
            case 'Swept Sine'
                set_param([block '/Reference Generator'],'LabelModeActiveChoice','Swept Sine');
                if visHandle ~= -1
                    set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
                    set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','0');
                else
                    disp('Warning: Visualization subsystem not found. Model scopes and visualizaiton aids may not function as expected.')
                end
                autoblksenableparameters(block, [], [],{'SSGroup'},{'ISGroup';'DLCGroup';'CRGroup';'SDGroup';'FHGroup';'DCGroup'});
                autoblksenableparameters(block,[],{'steerDir','t_start','xdot_r'},[],[],true);
                if simStopped && manOverride  && ~strcmp(prevType,manType) && (driverHandle == -1) 
                    set_param([vehSys '/Driver Commands'],'driverType','Predictive Driver');
                end
                simTime = 40;
            case 'Sine with Dwell'
                set_param([block '/Reference Generator'],'LabelModeActiveChoice','Sine with Dwell');
                if visHandle ~= -1
                    set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
                    set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','0');
                else
                    disp('Warning: Visualization subsystem not found. Model scopes and visualizaiton aids may not function as expected.')
                end
                autoblksenableparameters(block, [], [],{'SDGroup'},{'ISGroup';'DLCGroup';'CRGroup';'SSGroup';'FHGroup';'DCGroup'});
                autoblksenableparameters(block,{'steerDir','t_start','xdot_r'},[],[],[],true);
                if simStopped && manOverride  && ~strcmp(prevType,manType) && (driverHandle == -1) 
                    set_param([vehSys '/Driver Commands'],'driverType','Predictive Driver');
                end
                simTime = 25;
            case 'Constant Radius'
                set_param([block '/Reference Generator'],'LabelModeActiveChoice','Constant Radius');
                if visHandle ~= -1
                    set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','2');
                    set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','1');
                else
                    disp('Warning: Visualization subsystem not found. Model scopes and visualizaiton aids may not function as expected.')
                end
                autoblksenableparameters(block, [], [],{'CRGroup'},{'DLCGroup';'ISGroup';'SSGroup';'SDGroup';'FHGroup';'DCGroup'});
                autoblksenableparameters(block,{'steerDir','t_start','xdot_r'},[],[],[],true);
                if simStopped && manOverride  && ~strcmp(prevType,manType) && (driverHandle == -1) 
                    set_param([vehSys '/Driver Commands'],'driverType','Predictive Stanley Driver');  % this in turn will also update the driver params if needed
                end
                simTime = 60;
            case 'Fishhook'
                set_param([block '/Reference Generator'],'LabelModeActiveChoice','Fishhook');
                if visHandle ~= -1
                    set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
                    set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','0');
                else
                    disp('Warning: Visualization subsystem not found. Model scopes and visualizaiton aids may not function as expected.')
                end
                autoblksenableparameters(block, [], [],{'FHGroup'},{'ISGroup';'DLCGroup';'CRGroup';'SDGroup';'SSGroup';'DCGroup'});
                autoblksenableparameters(block,{'steerDir','t_start','xdot_r'},[],[],[],true);
                pFdbkChk = get_param(block,'pFdbk');
                if strcmp(pFdbkChk,'off')
                    autoblksenableparameters(block,{'tDwell1'},{'pZero'},[],[],'false')
                else
                    autoblksenableparameters(block,{'pZero'},{'tDwell1'},[],[],'false')
                end
                if simStopped && manOverride && ~strcmp(prevType,manType) && (driverHandle == -1) 
                    set_param([vehSys '/Driver Commands'],'driverType','Predictive Driver');
                end
                simTime = 40;
            case 'Drive Cycle'
                set_param([block '/Reference Generator'],'LabelModeActiveChoice','Drive Cycle');
                if visHandle ~= -1
                    set_param([vehSys '/Visualization/Scope Type'],'LabelModeActiveChoice','0');
                    set_param([vehSys '/Visualization/Vehicle XY Plotter'],'LabelModeActiveChoice','2');
                else
                    disp('Warning: Visualization subsystem not found. Model scopes and visualizaiton aids may not function as expected.')
                end
                autoblksenableparameters(block, [], [],{'DCGroup'},{'ISGroup';'CRGroup';'SSGroup';'SDGroup';'FHGroup';'DLCGroup'});
                autoblksenableparameters(block,[],{'steerDir','t_start','xdot_r'},[],[],true);
                if simStopped && manOverride && ~strcmp(prevType,manType) && (driverHandle == -1) 
                    set_param([vehSys '/Driver Commands'],'driverType','Longitudinal Driver');
                    set_param(block,'engine3D','Disabled');
                end
                loadedCycle = get_param([block '/Reference Generator/Drive Cycle/Drive Cycle Source'],'UserData');
                if ~isempty(loadedCycle)
                    %if workspace variable or other sources are selected
                    timeVec = loadedCycle.Time;
                    simTime = timeVec(end);
                else
                    simTime = 0;
                end
            otherwise
        end
        % update driver sldd, and 3D initial positions
        if simStopped && manOverride && ~strcmp(prevType,manType)
            update3DScene(block,manType);
            [~] = vdynblksmdlWSconfig(block,false);
            dictionaryObj = Simulink.data.dictionary.open('VirtualVehicleTemplate.sldd');
            dDataSectObj = getSection(dictionaryObj,'Design Data');
            list=VirtualAssemblyScenarioParaList(manType);
            for i=1:length(list)
                ddObj = getEntry(dDataSectObj,list{i}{1});
                setValue(ddObj,str2double(list{i}{2}));
            end

            saveChanges(dictionaryObj);
        end

        if simStopped && manOverride
            dictionaryObj = Simulink.data.dictionary.open('VirtualVehicleTemplate.sldd');
            dDataSectObj = getSection(dictionaryObj,'Design Data');
            ddObj = getEntry(dDataSectObj,'ScnSimTime');
            setValue(ddObj,simTime);
            saveChanges(dictionaryObj);
        end

        set_param(block,'prevType',manType)
    case 2  % update time button
        switch manType
            case 'Drive Cycle'
                loadedCycle = get_param([block '/Reference Generator/Drive Cycle/Drive Cycle Source'],'UserData');
                timeVec = loadedCycle.Time;
                simTime = timeVec(end);
            case 'Double Lane Change'
                simTime = 25;
            case 'Increasing Steer'
                simTime = 60;
            case 'Swept Sine'
                simTime = 40;
            case 'Sine with Dwell'
                simTime = 25;
            case 'Constant Radius'
                simTime = 60;
            case 'Fishhook'
                simTime = 40;
        end

        dictionaryObj = Simulink.data.dictionary.open('VirtualVehicleTemplate.sldd');
        dDataSectObj = getSection(dictionaryObj,'Design Data');
        ddObj = getEntry(dDataSectObj,'ScnSimTime');
        setValue(ddObj,simTime);
        saveChanges(dictionaryObj);

    case 3 % manual override button
        if manOverride
            autoblksenableparameters(block,[],[],[],{'simTimeGroup'},true);
        else
            autoblksenableparameters(block,[],[],{'simTimeGroup'},[],true);
        end
    case 4 % mask update for graphics enabling
        if sim3dEnabled
            autoblksenableparameters(block,[],[],{'engine3DSettingsGroup'},[],true);
        else
            autoblksenableparameters(block,[],[],[],{'engine3DSettingsGroup'},true);
        end

end
end
function update3DScene(block,manType)
sim3DBlkPath = block;
if strcmp(manType,'Double Lane Change')
    set_param(sim3DBlkPath,'SceneDesc','Double lane change');
else
    set_param(sim3DBlkPath,'SceneDesc','Open surface');
end
end