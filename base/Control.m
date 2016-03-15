classdef Control < handle
% CONTROL contains the local agents and data as well as the assignment
% object and fusion and results properties. It tracks the results and
% manages communication between all agents throughout the experiment. The
% experiment is run through the logic provided by handleAssignment and
% handleResults functions in the assignment object.
    
    properties
        agents % Array of LocalAgent objects
        data % Array of image indices
        assignment % Assignment type (options): 'random', 'gap', 'all', 'serial'
        fusion % Fusion type (ptions): 'sum', 'sml', 'mv'
        results % Table of classification results (numAgents x numTrials)
    end
    
    properties (Dependent)
        labels % Fused classification results (1 x numTrials)
    end
    
    events
        experimentComplete % Event which triggers the end of experiment
        beginExperiment % starts the experiment
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        
        function C = Control
        % CONTROL is the class constructor. It will set the preliminary
        % assignment and fusion methods.
            C.fusion = 'sum';
            C.assignment = cell(0);
            C.data = [];
            C.agents = cell(0);
            C.results = [];
        end
        
        function addAgent(obj,type,localPort,remoteHost,remotePort)
        % ADDAGENT will add a local agent to the agents array by calling
        % the class constructor of local agent and update the size of the
        % results field.
            index = length(obj.agents)+1;
            obj.agents{index} = LocalAgent(type,localPort,remoteHost,...
                remotePort,obj);
            updateControl(obj);
        end
        
        function addData(obj,newData)
        % ADDDATA will add data to control and update the size of the
        % results field.
            obj.data = [obj.data;newData(:)];
            updateControl(obj);
        end
        
        function changeAssignment(obj,assignmentType,varargin)
        % CHANGEASSIGNMENT updates the assignment object property
            if ~isempty(obj.assignment)
                delete(obj.assignment.beginExperimentListener);
                delete(obj.assignment);
            end
            switch assignmentType
                case 'all'
                    obj.assignment = All(obj);
                case 'serial'
                    try
                        obj.assignment = Serial(obj,varargin{1},...
                            varargin{2});
                    catch
                        warning('Inappropriate arguments for serial assignment.')
                        obj.assignment = All(obj);
                    end
                case 'serialPrototype'
                    try
                        obj.assignment = SerialPrototype(obj,...
                            varargin{1},varargin{2});
                    catch
                        warning('Inappropriate arguments for serial assignment.')
                        obj.assignment = All(obj);
                    end
                case 'gap'
                    try
                        obj.assignment = GAP(obj,varargin{1},varargin{2});
                    catch
                        warning('Inappropriate arguments for gap assignment.')
                        obj.assignment = All(obj);
                    end
                otherwise
                    warning('Not a valid assignment type. Using all.');
                    obj.assignment = All(obj);
            end
        end
        
        function updateControl(obj)
        % UPDATE will update the size of the results field according
        % to the current size of agents and data as well as the properties
        % of assignment.
            if ~isempty(obj.assignment)
                updateAssignment(obj.assignment);
            end
            obj.results = zeros(length(obj.agents),length(obj.data));
        end
        
        %------------------------------------------------------------------
        % System-level:
        
        function start(obj)
        % START will populate the results property using the given
        % assignment module
            addResultsListener(obj.assignment);
            handleAssignment(obj.assignment);
        end
        
        function terminate(obj)
        % TERMINATE will close and delete the direct interface sockets for
        % all agents in the control object.
            agentIndex = 1:length(obj.agents);
            for i = agentIndex
                terminate(obj.agents{i});
            end
        end
        
        %------------------------------------------------------------------
        % Property access:
        
        function Y = get.labels(obj)
        % GET.LABELS is the access command for labels. It will call the
        % given fusion function to determine the pseudo-labels in
        % real-time. Options: 'SML', 'sum', 'MV'.
            switch obj.fusion
                case 'sml'
                    try
                        y = sml(obj.results);
                    catch
                        warning('Something was wrong with SML. Using mv.');
                        y = mode(obj.results,2);
                    end
                case 'sum'
                    y = sum(obj.results,1);
                    y(y>=0) = 1;
                    y(y<0) = -1;
                case 'mv'
                    y = mode(obj.results,1);
                otherwise
                    error('Not a valid fusion method.');
            end
            Y = y;
        end
        
        %------------------------------------------------------------------
    end
    
end
