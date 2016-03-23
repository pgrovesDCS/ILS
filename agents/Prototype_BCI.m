classdef Prototype_BCI < RemoteAgent
% PROTOTYPE_BCI is a child of the LocalAgent superclass to be used for
% system testing and development. It generates an image classification
% randomly according to a specified accuracy and delay of 1e-1.
    
    properties
        accuracy % Accuracy of prototype agent
        delay % Delay of prototype agent
    end
    
    methods
        % -----------------------------------------------------------------
        % Class constructor:
        
        function A = Prototype_BCI(remotePort,agentAccuracy)
            if nargin < 1
                error('Too few parameters for class construction.');
            end
            A@RemoteAgent('prototype_bci',remotePort);
            A.delay = 1e-1;
            if nargin == 2
                A.accuracy = agentAccuracy;
            else
                A.accuracy = rand;
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
            else
                Y = zeros(length(X),1);
                Y(rand(length(X),1)<obj.accuracy) = 1;
                pause(obj.delay);
                fwrite(obj.socket,Y(:));
                fprintf('Prototype_BCI completed classification of %u images.\n',...
                    length(X))
            end
        end
        
        %------------------------------------------------------------------
        
    end
    
end