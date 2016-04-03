classdef GAP < Assignment
% GAP is an assignment architecture that assigns images in parallel
% according to a generalized assignment problem (GAP) formulation. It
% infers agent reliability and image label confidence from the spectral
% meta-learner (SML) at the completion of each iteration. These results are
% used for the GAP formulation in the subsequent iteration. It requires
% both an iteration interval (in seconds) and a confidence threshold, which
% specifies the confidence of an image label to consider it complete and no
% longer assign it.
    
    properties
        iterationStatus % Boolean array which tracks the receipt of classification results
        iterationListener % Listener for iterationComplete event
        agentIndex % Boolean array for referencing agents
        value % numAgents*numImages array of assignment values
        cost % numAgents*numImages array of assignment costs
        budget % numAgents*1 array of budget for each agent for each iteration
        agentReliability % numAgents*1 array of the current reliability estimate
        imageConfidence % numImages*1 array of current confidence in label
        imageCompletion % numImages*1 boolean of completion of images
        threshold % confidence threshold for an image to be complete
    end
    
    events
        iterationComplete % Event which triggers next iteration of assignment
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        
        function A = GAP(control,iterationInterval,confThreshold)
        % ALL is the class constructor for assignment type all. It calls
        % the superclass constructor of assignment and adds a iteration
        % listener.
            A@Assignment(control,'all');
            A.iterationListener = addlistener(A,'iterationComplete',...
                @A.handleAssignment);
            A.agentIndex = false(length(control.agents),1);
            A.iterationStatus = A.agentIndex;
            A.value = ones(size(A.assignmentMatrix));
            A.cost = zeros(size(A.agentIndex));
            for i = 1:length(A.cost)
                switch control.agents{i}.type
                    case 'cv'
                        A.cost(i) = 1e-2;
                    case 'rsvp'
                        A.cost(i) = 1e-1;
                    case 'human'
                        A.cost(i) = 1;
                    otherwise
                        A.cost(i) = inf;
                end
            end
            A.budget = iterationInterval*ones(size(A.cost));
            A.agentReliability = zeros(size(A.cost));
            A.imageConfidence = zeros(length(control.data),1);
            A.imageCompletion = false(size(A.imageConfidence));
            A.threshold = confThreshold;
        end
        
        %------------------------------------------------------------------
        % System-level:
        
        function handleAssignment(obj,src,event)
        % HANDLEASSIGNMENT generates an all true assignment matrix and
        % assigns the images on the first call. When called again, it ends
        % the experiment.
            switch event.EventName
                case 'iterationComplete'
                    getAssignment(obj);
                case 'beginExperiment'
                    numAgents = length(obj.control.agents);
                    numImages = numAgents*(numAgents+1);
                    numImages = min(numImages,size(obj.assignmentMatrix,2));
                    initAssignment = randperm(length(obj.imageCompletion));
                    initAssignment = initAssignment(1:numImages);
                    obj.assignmentMatrix(:,initAssignment) = true;
                    for i = 1:length(obj.agentIndex)
                        if ~any(obj.assignmentMatrix(i,:))
                            obj.iterationStatus(i) = true;
                        end
                    end
                    assignImages(obj);
            end
        end
        function handleResults(obj,src,event)
        % HANDLERESULTS populates the results table in control as results
        % are ready. When all results are returned, it calls
        % handleAssignment.
            for i = 1:length(obj.control.agents)
                obj.agentIndex(i) = eq(obj.control.agents{i},src);
            end
            obj.control.results(obj.agentIndex,obj.assignmentMatrix(obj.agentIndex,:))...
                = readResults(src)';
            obj.iterationStatus(obj.agentIndex) = true;
            fprintf('Results received from Agent %u.\n',...
                find(obj.agentIndex));
            if all(obj.iterationStatus)
                obj.iterationStatus(:) = false;
                notify(obj,'iterationComplete');
                return
            end
        end
        function terminate(obj)
        % TERMINATE will delete all listeners in the assignment
            delete(obj.iterationListener);
            terminate@Assignment(obj);
        end
        function resetAssignment(obj)
        % RESETASSIGNMENT will return assignment to initial state for a
        % follow-on experiment
            obj.agentIndex(:) = false;
            obj.iterationStatus(:) = false;
            obj.assignmentMatrix(:) = false;
            obj.value(:) = 1;
            obj.agentReliability(:) = 0;
            obj.imageConfidence(:) = 0;
            obj.imageCompletion(:) = false;
        end
                
        %------------------------------------------------------------------
        % Dependencies:
        
        function getAssignment(obj)
        % GETASSIGNMENT uses the GAP formulation to generate a new
        % assignmentMatrix.
            [~,score,obj.agentReliability] = sml(obj.control.results);
            obj.imageConfidence(~obj.imageCompletion) = abs(score(~obj.imageCompletion));
            temp = obj.imageCompletion(~obj.imageCompletion);
            temp(obj.imageConfidence(~obj.imageCompletion)>=obj.threshold) = true;
            obj.imageCompletion(~obj.imageCompletion) = temp;
            if all(obj.imageCompletion)
                notify(obj.control,'experimentComplete');
                return
            end
            temp = max(obj.imageConfidence) + repmat(obj.agentReliability,1,size(obj.value,2))...
                - repmat(obj.imageConfidence',size(obj.value,1),1);
            temp(temp<0) = 0;
            temp(obj.assignmentMatrix) = 0;
            obj.assignmentMatrix(:) = false;
            temp(obj.value==0) = 0;
            obj.value = temp;
            if all(obj.value(:,~obj.imageCompletion)==0)
                notify(obj.control,'experimentComplete');
                return
            end
            [v,Aineq,bineq,Aeq,beq] = convertProblem(...
                obj.value(:,~obj.imageCompletion),...
                repmat(obj.cost,1,length(find(~obj.imageCompletion))),...
                obj.budget);
            % Run GAP (written by Addison)
%             tempAssign = branchAndBound(v,1e2*Aineq,1e2*bineq,Aeq,beq,...
%                 'greedy');
            % Run MATLAB solver
            intcon = 1:length(v);
            lb = zeros(length(v),1);
            ub = ones(length(v),1);
            options = optimoptions('intlinprog','Display','none',...
                'CutGeneration','basic');
            tempAssign = intlinprog(-v,intcon,Aineq,bineq,Aeq,beq,...
                lb,ub,options);
            try
                obj.assignmentMatrix(:,~obj.imageCompletion) = ...
                    reshape(tempAssign,length(obj.budget),[])==1;
            catch
                warning('Problem has no feasible solutions.');
                notify(obj.control,'experimentComplete');
                return
            end
            for i = 1:length(obj.agentIndex)
                if ~any(obj.assignmentMatrix(i,:))
                    obj.iterationStatus(i) = true;
                end
            end
            assignImages(obj);
        end
    
    %----------------------------------------------------------------------
    end
end