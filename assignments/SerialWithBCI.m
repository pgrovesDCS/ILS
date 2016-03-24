classdef SerialWithBCI < Assignment
% SERIALWITHBCI is an assignment type which works with one human, one BCI,
% and one CV. Images are assigned in order to the CV according to the batch
% size, as the CV results arrive, some of those images are assigned to the
% BCI agent. In turn, as those return, some images are assigned to the
% human according. Both assignment probabilities are handled with policy
% variables. The BCI and human results are accumulated asynchronously while
% the control process iterates through assigning the entire database to the
% CV.
    
    properties
        policy % n*1 vector which contains the release probability for each class
        humanIndex % index of human agent
        bciIndex % index of BCI agent
        cvIndex % index of CV agent
        batchSize % size of assignment blocks to CV
        iterationListener % listener for iterationComplete event
        humanAssignment % current human assignment iteration awaiting results
        humanAssignmentMax % most recent assignment iteration for human
        humanAssignmentTracker % array of all images assigned to human
        bciAssignment % current BCI assignment iteration awaiting results
        bciAssignmentMax % most recent assignment iteration for BCI
        bciAssignmentTracker % array of all images assigned to BCI
        finalHumanIteration % boolean which identifies the human beginning the final batch
        finalBCIIteration % boolean which identifies the BCI beginning the final batch
        finalCVIteration % boolean which identifies the CV beginning the final batch
    end
    
    events
        iterationComplete % event which signifies the completion of a batch of CV assignments
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        
        function A = SerialWithBCI(control,batch,policy_human,policy_bci)
        % SERIAL is the class constructor for assignment type serial. It
        % calls the superclass constructor of Assignment and initializes
        % all necessary properties and listeners.
            A@Assignment(control,'serial');
            A.batchSize = batch;
            A.policy_human = policy_human;
            A.policy_bci = policy_bci;
            for i = 1:length(control.agents)
                switch control.agents{i}.type 
                    case 'human' | 'prototype_human'
                        A.humanIndex = i;
                    case 'bci' | 'prototype_bci'
                        A.bciIndex = i;
                    case 'cv' | 'prototype_cv'
                        A.cvIndex = i;
                end
            end
            if isempty(A.humanIndex) || isempty(A.cvIndex) || isempty(A.bciIndex)
                error('Serial policy requires a human and a CV agent.')
            end
            if A.humanIndex > 3 || A.cvIndex > 3 || A.bciIndex > 3
                error('Too many agents have been added to the sytem.')
            end
            A.iterationListener = addlistener(A,'iterationComplete',...
                @A.handleAssignment);
            A.humanAssignment = 0;
            A.humanAssignmentMax = 0;
            A.humanAssignmentTracker = zeros(length(A.control.data),1);
            A.bciAssignment = 0;
            A.bciAssignmentMax = 0;
            A.bciAssignmentTracker = zeros(length(A.control.data),1);
            A.finalHumanIteration = false;
            A.finalBCIIeration = false;
            A.finalCVIteration = false;
        end
        
        %------------------------------------------------------------------
        % System-level:
        
        function handleAssignment(obj,src,event)
        % HANDLEASSIGNMENT handles three different events. When notified by
        % Experiment to start the experiment, it generates an initial
        % assignment to the CV. On subsequent calls from iterationComplete,
        % this is the event for the processing of results from the previous
        % CV assignment, it assigns the next batch of images to the CV. On
        % subsequent calls from humanUpToDate, it completes the experiment
        % if all images have been assigned to the CV.
            switch event.EventName
                case 'beginExperiment'
                    if obj.batchSize < size(obj.assignmentMatrix,2)
                        obj.assignmentMatrix(obj.cvIndex,...
                            1:obj.batchSize) = true;
                    else
                        obj.assignmentMatrix(obj.cvIndex,1:end) = true;
                        obj.finalCVIteration = true;
                    end
                case 'iterationComplete'
                    prevIndex = find(obj.assignmentMatrix(obj.cvIndex,:),1,'last');
                    obj.assignmentMatrix(obj.cvIndex,:) = false;
                    if (prevIndex+obj.batchSize) < size(obj.assignmentMatrix,2)
                        obj.assignmentMatrix(obj.cvIndex,...
                            (prevIndex+1):(prevIndex+obj.batchSize)) = true;
                    else
                        obj.assignmentMatrix(obj.cvIndex,...
                            (prevIndex+1):end) = true;
                        obj.finalCVIteration = true;
                    end
                otherwise
                    warning('Control flow should not be here.');
                    return
            end
            assignImages(obj,obj.cvIndex);
        end
        function handleResults(obj,src,event)
        % HANDLERESULTS handles two events: classification results from the
        % human or from the CV. These results are populated in Control and
        % trigger distinct calls to handleAssignment through different
        % events.
            fprintf('Results received from %s.\n',src.type);
            if strcmp(src.type,'human')
                obj.humanAssignment = obj.humanAssignment + 1;
                obj.control.results(obj.humanIndex,...
                    obj.humanAssignmentTracker==obj.humanAssignment)...
                    = readResults(src)';
                if obj.humanAssignment == obj.humanAssignmentMax
                    if obj.finalIteration
                        notify(obj.control,'experimentComplete');
                    end
                end
            else
                results = readResults(src)';
                obj.control.results(obj.cvIndex,...
                    obj.assignmentMatrix(obj.cvIndex,:)) = results;
                newAssignment = getHumanAssignment(obj,results);
                if any(newAssignment)
                    obj.humanAssignmentMax = obj.humanAssignmentMax + 1;
                    obj.humanAssignmentTracker(newAssignment)...
                        = obj.humanAssignmentMax;
                    obj.assignmentMatrix(obj.humanIndex,:) = false;
                    obj.assignmentMatrix(obj.humanIndex,:) = ...
                        obj.humanAssignmentTracker == obj.humanAssignmentMax;
                    assignImages(obj,obj.humanIndex);
                    if obj.finalCVIteration
                        obj.finalIteration = true;
                    end
                elseif obj.finalCVIteration
                    notify(obj.control,'experimentComplete');
                end
                notify(obj,'iterationComplete');
            end
        end
        function terminate(obj)
        % TERMINATE will delete all listeners in the assignment
            delete(obj.iterationListener);
            terminate@Assignment(obj);
        end
        
        %------------------------------------------------------------------
        % Dependencies:
        
        function tasks = getHumanAssignment(obj,cvResults)
        % GETHUMANASSIGNMENT assigns a subset of images to the human
        % according to the CV results and policy.
            temp = false(size(cvResults));
            temp(cvResults==-1) = rand(size(temp(cvResults==-1))) < obj.policy(1);
            temp(cvResults==1) = rand(size(temp(cvResults==1))) < obj.policy(2);
            tasks = obj.assignmentMatrix(obj.cvIndex,:);
            tasks(tasks) = temp;
        end
        
        %------------------------------------------------------------------
    end
    
end
