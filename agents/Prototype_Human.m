classdef Prototype_Human < RemoteAgent
% PROTOTYPE_Human is a child of the LocalAgent superclass to be used for
% system testing and development. It generates an image classification
% randomly according to a specified accuracy and delay of 1.
    
    properties
        accuracy % Accuracy of prototype agent
        delay % Delay of prototype agent
        trueBehavior % Delay is manifest in agent (boolean)
    end
    
    methods
        % -----------------------------------------------------------------
        % Class constructor:
        
        function A = Prototype_Human(remotePort,agentAccuracy,trueBehavior)
            if nargin < 1
                error('Too few parameters for class construction.');
            end
            A@RemoteAgent('prototype_human',remotePort);
            A.delay = 1;
            if nargin >= 2
                A.accuracy = agentAccuracy;
            else
                A.accuracy = rand;
            end
            if nargin == 3
                A.trueBehavior = trueBehavior;
            else
                A.trueBehavior = false;
            end
        end
        
        %------------------------------------------------------------------
        % System-Level:
        
        function Y = classifyImages(obj,src,event)
        % CLASSIFYIMAGES is a callback function which is initiated by the
        % receipt of an image assignment from a local agent. It will
        % classify images or terminate the agent upon receipt of the
        % 'complete' command.
            X = fread(obj.socket);
            if strcmp(char(X)','complete')
                terminate(obj);
            elseif strcmp(char(X)','test')
                return
            else
                n = length(X);
                Y = zeros(n,1);
                Y(rand(n,1)<obj.accuracy) = 1;
                if obj.trueBehavior
                    pause(n*obj.delay);
                end
                fwrite(obj.socket,Y(:));
                fprintf('Prototype_Human completed classification of %u images.\n',...
                    n)
            end
        end
        
        %------------------------------------------------------------------
        
    end
    
end