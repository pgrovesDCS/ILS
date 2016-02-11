classdef (Abstract) RemoteAgent < Agent
% REMOTEAGENT is the remote agent and a child of the Agent superclass.
% It will receive image classification assignments from the local agent,
% classify the images, and return the results.
    
    properties
        imdir % Image directory
        port % Local port of remote agent
        socket % Direct interface communication with local agent
        status % Boolean variable which signifies a connection with the local agent
    end
    
    methods
        % -----------------------------------------------------------------
        % Class constructor:
        
        function A = RemoteAgent(type,remotePort,imageDirectory)
        % REMOTEAGENT is the class constructor for a remote agent. It will
        % be called on a remote host and broadcast its IP address and port
        % to the machine which is hosting the experiment. Upon establishing
        % a connection with the experiment, it will wait for a message from
        % a local agent.
            A@Agent(type);
            A.status = false;
            A.port = remotePort;
            if nargin >= 2
                % **This has to be hard-coded for the time being**
                localHost = 'localHost';
                localPort = 2000;
                if nargin == 3
                    addpath(imageDirectory);
                    A.imdir = dir(imageDirectory);
                    A.imdir = A.imdir(3:end);
                else
                    A.imdir = '';
                end
            else
                error('Not enough input arguments to create RemoteAgent.')
            end
            A.socket = udp(localHost,localPort,'LocalHost',...
                'localHost','LocalPort',A.port);
            fopen(A.socket);
            fwrite(A.socket,A.type);
            fclose(A.socket);
            delete(A.socket);
            waitForAgent(A);
        end
        
        %------------------------------------------------------------------
        % System-level:
        
        function start(obj)
        % START moves a remote agent into an on-line status so that it can
        % receive image assignments. It should be called after first
        % establishing a direct interface with the local agent.
            if obj.status
                fopen(obj.socket);
                obj.socket.readasyncmode = 'continuous';
                obj.socket.datagramreceivedfcn = @obj.classifyImages;
            else
                warning('Remote agent is not connected to local agent.')
                return
            end
        end
        
        %------------------------------------------------------------------
        % Dependencies:
        
        function waitForAgent(obj)
        % WAITFORAGENT scans all IP broadcasts for an incoming message from
        % the local agent. It calls UPDATESOCKET upon receipt of an
        % incoming message.
            obj.socket = udp('0.0.0.0','LocalHost','localHost',...
                'LocalPort',obj.port);
            fopen(obj.socket);
            obj.socket.readasyncmode = 'continuous';
            obj.socket.datagramreceivedfcn = @obj.updateSocket;
        end
        
        function updateSocket(obj,src,event)
        % UPDATESOCKET creates the direct interface connection with the
        % local agent, sets the status field to true, and starts the remote
        % agent.
            fread(obj.socket);
            fclose(obj.socket);
            delete(obj.socket);
            localHost = event.Data.DatagramAddress;
            localPort = event.Data.DatagramPort;
            obj.socket = udp(localHost,localPort,'LocalHost',...
                'localHost','LocalPort',obj.port);
            obj.status = true;
            fprintf('Agent is connected to the Image Labeling System.\n')
            start(obj)
        end
        
        function terminate(obj)
        % TERMINATE ends the direct interface communication session.
            fclose(obj.socket);
            delete(obj.socket);
            fprintf('Agent terminated.\n')
        end
        
        function image = getImages(obj,index)
        % GETIMAGE loads an image from the specified directory. It can take
        % a vector argument and will return a cell array of images.
            if strcmp(obj.imdir,'')
                warning('Function not available for prototype.');
            end
            image = cell(length(index),1);
            for i = 1:length(index)
                image{i} = imread(obj.imdir(index(i)).name);
            end
        end
        
        %------------------------------------------------------------------
    end
    
    methods (Abstract)
        classifyImages(obj,src,event)
    end
    
end