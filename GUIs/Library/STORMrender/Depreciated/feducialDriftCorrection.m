function [dxc,dyc,correctedTrajectory,rawTrajectory,drift_error] = feducialDriftCorrection(input1,varargin)
%--------------------------------------------------------------------------
% [dxc,dyc] = feducialDriftCorrection(binname)
% [dxc,dyc] =  feducialDriftCorrection(mlist)
% feducialDriftCorrection([],'daxname',daxname,'mlist',mlist,...);
% targetmlist = FeducialDriftCorrection(beadlist,'target',targetmlist); 
% targetmlist = FeducialDriftCorrection(beadlist,'target',targetmlist,...
%                  'samplingrate', 60); 
%--------------------------------------------------------------------------
% Required Inputs
%
% daxname / string - name of daxfile to correct drift
% or 
% mlist / structure 
% 
% mlist.xc = mlist.x - dxc(mlist.frame);
% mlist.yc = mlist.y - dyc(mlist.frame); 
%--------------------------------------------------------------------------
% Optional Inputs
%
%  'Option Name' / Class / Default 
% 'spotframe' / double / =startframe
%                -- frame to use to ID the feducial bead positions. 
% 'startframe' / double / 1  
%               -- first frame to start drift analysis at
% 'maxdrift' / double / 2.5 
%               -- max distance a feducial can get from its starting 
%                  position and still be considered the same molecule
% 'integrateframes' / double / 500
% 'fmin' / double / .5
%               -- fraction of frames which must contain feducial
% 'nm per pixel' / double / 158 
%               -- nm per pixel in camera
% 'showplots' / boolean / true
% 'showextraplots' / boolean / false
% 'clearfigs'
% 
%--------------------------------------------------------------------------
% Outputs
% dxc,dyc -- computed drift per frame.  To correct drift, write:
%             mlist.xc = mlist.x - dxc(mlist.frame);
%             mlist.yc = mlist.y - dyc(mlist.frame); 
%--------------------------------------------------------------------------
% Alistair Boettiger
% boettiger.alistair@gmail.com
% June 10th, 2013
%
% Version 1.0
%--------------------------------------------------------------------------
% Creative Commons License 3.0 CC BY  
%--------------------------------------------------------------------------

global scratchPath

%--------------------------------------------------------------------------
%% Default Parameters
%--------------------------------------------------------------------------

daxname = [];
startframe = 1; % frame to use to find feducials
spotframe = [];
maxdrift = 2.5; % max distance a feducial can get from its starting position and still be considered the same molecule
integrateframes = 200; % number of frames to integrate
fmin = .8; 
npp = 160;
showplots = true;
showextraplots = false; 
binname = '';
mlist = []; 
samplingrate = 1;
targetmlist = [];
if ischar(input1)
    binname = input1;
elseif isstruct(input1)
    mlist = input1;
end

% abinname = [daxname(1:end-4),'_alist.bin'];
% alist = ReadMasterMoleculeList(abinname);
% figure(10); clf; plot(alist.x,alist.y,'k.');
% hold on; plot(alist.xc,alist.yc,'r.');



%--------------------------------------------------------------------------
% Parse variable input
%--------------------------------------------------------------------------
if nargin > 2
    if (mod(length(varargin), 2) ~= 0 ),
        error(['Extra Parameters passed to the function ''' mfilename ''' must be passed in pairs.']);
    end
    parameterCount = length(varargin)/2;
    for parameterIndex = 1:parameterCount,
        parameterName = varargin{parameterIndex*2 - 1};
        parameterValue = varargin{parameterIndex*2};
        switch parameterName
            case 'binname'
                binname = CheckParameter(parameterValue,'string','binname');
            case 'mlist'
                mlist = CheckParameter(parameterValue,'struct','mlist');
            case 'target'
                targetmlist = CheckParameter(parameterValue,'struct','targetmlist');
            case 'samplingrate'
                samplingrate = CheckParameter(parameterValue,'struct','samplingrate');
            case 'spotframe'
                spotframe  = CheckParameter(parameterValue,'positive','startframe');
            case 'startframe'
                startframe = CheckParameter(parameterValue,'positive','startframe');
            case 'maxdrift'
                maxdrift = CheckParameter(parameterValue,'positive','maxdrift');
            case 'integrateframes'
                integrateframes = CheckParameter(parameterValue,'positive','integrateframes');
            case 'fmin'
                fmin = CheckParameter(parameterValue,'positive','fmin');
            case 'nm per pixel'
                npp = CheckParameter(parameterValue,'positive','nm per pixel');
            case 'showplots'
                showplots = CheckParameter(parameterValue,'boolean','showplots');
            case 'showextraplots'
                showextraplots = CheckParameter(parameterValue,'boolean','showextraplots');
            otherwise
                error(['The parameter ''' parameterName ''' is not recognized by the function ''' mfilename '''.']);
        end
    end
end


%--------------------------------------------------------------------------
%% Main Function
%--------------------------------------------------------------------------

integrateframes = ceil(integrateframes/samplingrate); 

if ~isempty(binname)
    k = regexp(binname,'_');
    daxname = [binname(1:k(end)-1),'.dax'];
end

if isempty(mlist)
    mlist = ReadMasterMoleculeList(binname,'verbose',false);
end
if ~isempty(binname) && ~isempty(daxname)
    daxfile = ReadDax(daxname,'startFrame',startframe,'endFrame',startframe+100,'verbose',false);
end

if isempty(spotframe)
    spotframe = startframe;
end

%%

% Automatically ID feducials
%-------------------------------------------------

% Step 1, find all molecules that are "ON" in startframe.
if spotframe == 1
    spotframe = min(mlist.frame);
end
if startframe == 1
    startframe = min(mlist.frame);
end
p1s = mlist.frame==spotframe;
x1s = mlist.x(p1s);
y1s = mlist.y(p1s);

if showextraplots
   figure(2); clf; 
   plot(mlist.x,mlist.y,'k.','MarkerSize',1);
   hold on;
   plot(x1s,y1s,'bo');
   legend('all localizations','startframe localizations'); 
end

% Reject molecules that are too close to other molecules
if length(x1s) > 1
    [~,dist] = knnsearch([x1s,y1s],[x1s,y1s],'K',2);
    nottooclose = dist(:,2)>2*maxdrift;
    x1s = x1s(nottooclose);
    y1s = y1s(nottooclose);
end    

% Feducials must be ID'd in at least fmin fraction of total frames
fb =[x1s-maxdrift, x1s + maxdrift,y1s-maxdrift, y1s + maxdrift];
Tframes = zeros(length(x1s),1);
for i=1:length(x1s)
    inbox = mlist.x > fb(i,1) & mlist.x < fb(i,2) & ...
        mlist.y > fb(i,3) & mlist.y < fb(i,4) & ...
        mlist.frame > startframe;
   Tframes(i) = sum(inbox);
end
feducials = Tframes > fmin*(max(mlist.frame)-startframe); 

if showplots
    figure(1); clf; 
    if ~isempty(daxname)
        imagesc(daxfile(:,:,1));
    end
    colormap hot;
    hold on;
    plot(x1s,y1s,'co');
end

if sum(feducials) == 0 
   error('no feducials found. Try changing fmin or startframe');  
end
x1s = x1s(feducials);
y1s = y1s(feducials);
fb = fb(feducials,:);
feducial_boxes = [fb(:,1),fb(:,3),...
    fb(:,2)-fb(:,1),fb(:,4)-fb(:,3)];

if showplots
    colormap gray;
    figure(1); hold on; 
    plot(x1s,y1s,'k.');
end

% Record position of feducial in every frame
Nfeducials = length(x1s);
Nframes = double(max(mlist.frame));
rawTrajectory = NaN*ones(Nframes,Nfeducials,2);
for i=1:Nfeducials
    incirc = mlist.x > fb(i,1) & mlist.x <= fb(i,2) & mlist.y > fb(i,3) & mlist.y <= fb(i,4);
    rawTrajectory(mlist.frame(incirc),i,1) = double(mlist.x(incirc));
    rawTrajectory(mlist.frame(incirc),i,2) = double(mlist.y(incirc));
    if showplots
        figure(1); hold on; 
        rectangle('Position',feducial_boxes(i,:),'Curvature',[1,1]);
        plot( mlist.x(incirc), mlist.y(incirc),'r.','MarkerSize',1);
    end
end


% Determine best-fit feducial using median feducial for first pass
%----------------------------------------------------
% subtract starting position from each trajectory
dx = rawTrajectory(:,:,1)-repmat(rawTrajectory(startframe,:,1),Nframes,1);
dy = rawTrajectory(:,:,2)-repmat(rawTrajectory(startframe,:,2),Nframes,1);

% compute median drift 
dxmed = nanmedian(dx,2); % xdrift per frame
dymed = nanmedian(dy,2); % ydrift per frame

goodframes = startframe:Nframes; 
% correct drift in feducials;
xc = rawTrajectory(goodframes,:,1)-repmat(dxmed(goodframes),1,Nfeducials);
yc = rawTrajectory(goodframes,:,2)-repmat(dymed(goodframes),1,Nfeducials);

totMovement = zeros(Nfeducials,1);
for j=1:Nfeducials
    totMovement(j) = nanmedian(abs(dx(startframe:end,j)) + ...
                  abs(dy(startframe:end,j)));
end

[~,guide_dot] = min(abs(totMovement)); 
drift_error = abs(min(totMovement(guide_dot) - totMovement([1:guide_dot-1,guide_dot+1:end]))*npp);

disp(['residual drift error = ', num2str(drift_error),' nm']); 
if showplots
    figure(1); hold on; colormap jet;
    plot(xc(:,guide_dot),yc(:,guide_dot),'w.','MarkerSize',1);
end


% Apply moving average filter to remove frame-to-frame fit noise
%----------------------------------------------------------------
% Moving average filter
x = dx(:,guide_dot); % xdrift per frame
y = dy(:,guide_dot); % ydrift per frame
dxc = fastsmooth(x,integrateframes,1,1);
dyc = fastsmooth(y,integrateframes,1,1);
dxp = dxc(integrateframes+1:end-integrateframes);
dyp = dyc(integrateframes+1:end-integrateframes);
if showplots
    z = zeros(size(dxp')); 
    col = [double(1:Nframes-1-2*integrateframes),NaN];  % This is the color, vary with x in this case.
    figure(1); clf; colordef white; 
    surface([dxp';dxp'+.001]*npp,[dyp';dyp'+.001]*npp,[z;z],[col;col],...
            'facecol','no',...
            'edgecol','interp',...
            'linew',1);    
        set(gcf,'color','w'); 
        xlabel('nm'); 
        ylabel('nm'); 
end


% correct drift
mlist.xc = mlist.x - dxc(mlist.frame);
mlist.yc = mlist.y - dyc(mlist.frame); 

% export feducial coordinates if desired
correctedTrajectory = zeros(length(dxc),Nfeducials,2);
for n = 1:Nfeducials;
    correctedTrajectory(:,n,1) = rawTrajectory(:,n,1)- dxc;
    correctedTrajectory(:,n,2) = rawTrajectory(:,n,2)- dyc;
end

%% Extra plots
%------------------------------------------------
if showextraplots
    figure(2); clf; 
    plot(mlist.x,mlist.y,'r.',mlist.xc,mlist.yc,'k.','MarkerSize',1);
end

% show drift traces for all feducials
if showextraplots
    figure(3); clf;
    for i=1:Nfeducials
        figure(3);
        subplot(Nfeducials,2,i*2-1); plot(dx(startframe:end,i),'.','MarkerSize',1);
        subplot(Nfeducials,2,i*2); plot(dy(startframe:end,i),'.','MarkerSize',1);
    end
    figure(4); clf; subplot(1,2,1); plot(dx(startframe:end,:),'MarkerSize',1);
    subplot(1,2,2); plot(dy(startframe:end,:),'MarkerSize',1);
end

%%  Apply drift correction to a new mlist

if ~isempty(targetmlist); 
    % differential sampling
    if samplingrate > 1
        targetFrames = max(targetmlist.frame); 
        x_drift = interp1(1:Nframes,xdc,1:targetFrames);
        y_drift = interp1(1:Nframes,xdc,1:targetFrames);
    else 
        missingframes = max(targetmlist.frame) - length(xdc);
        x_drift = [xdc; zeros(missingframes,1)]; %#ok<*AGROW>
        y_drift = [ydc; zeros(missingframes,1)];
    end
    targetmlist.xc = targetmlist.x - x_drift(targetmlist.frame);
    targetmlist.yc = targetmlist.y - y_drift(targetmlist.frame); 

    % overload dxc;
    dxc = targetmlist; 
end