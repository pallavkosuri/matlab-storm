function RunMenuDisplayOps(hObject, eventdata, handles)
% Executes when DisplayOps is selected from dropdown menu.

global SR
dlg_title = 'More Display Options';
num_lines = 1;
Dprompt = {
    'Display Z as color',...
    'Number of Z-steps',...
    'Z range (nm)',...
    'hide poor z-fits',...
    'Dot scale',...
    'scalebar in nm (0 for off)',...
    'nm per pixel',...
    'verbose'...
    'Plot corrected positions (xc, yc)',...
    'Color map',...
    'Display resolution'};
default_Dopts{1} = num2str(SR{handles.gui_number}.DisplayOps.ColorZ);
default_Dopts{2} = num2str(SR{handles.gui_number}.DisplayOps.Zsteps);
default_Dopts{3} = strcat('[',num2str(SR{handles.gui_number}.DisplayOps.zrange),']');
default_Dopts{4} = num2str(SR{handles.gui_number}.DisplayOps.HidePoor);
default_Dopts{5} = strcat('[',num2str(SR{handles.gui_number}.DisplayOps.DotScale),']');
default_Dopts{6} = num2str(SR{handles.gui_number}.DisplayOps.scalebar);
default_Dopts{7} = num2str(SR{handles.gui_number}.DisplayOps.npp);
default_Dopts{8} = num2str(SR{handles.gui_number}.DisplayOps.verbose); 
default_Dopts{9} = num2str(SR{handles.gui_number}.DisplayOps.CorrDrift);
default_Dopts{10} = num2str(SR{handles.gui_number}.DisplayOps.clrmap);
default_Dopts{11} = num2str(SR{handles.gui_number}.DisplayOps.resolution);
% if the menu is screwed up, reset 
try
default_Dopts = inputdlg(Dprompt,dlg_title,num_lines,default_Dopts);
catch er
    disp(er.message)
    default_Dopts = {
    'false',...
    '8',...
    '[-500,500]',...
    'false',...
    '4',...
    '500',...
    '160',...
    'true',...
    'true',...
    'hsv',...
    '512'};
end
if length(default_Dopts) > 1 % Do nothing if canceled
    newResolution = eval(default_Dopts{11});
    if SR{handles.gui_number}.DisplayOps.resolution ~= newResolution
        updateRes = true;
    else
        updateRes = false;
    end
    
    SR{handles.gui_number}.DisplayOps.ColorZ = eval(default_Dopts{1}); 
    SR{handles.gui_number}.DisplayOps.Zsteps = eval(default_Dopts{2});
    SR{handles.gui_number}.DisplayOps.zrange = eval(default_Dopts{3});
    SR{handles.gui_number}.DisplayOps.HidePoor = eval(default_Dopts{4});
    SR{handles.gui_number}.DisplayOps.DotScale = eval(default_Dopts{5});
    SR{handles.gui_number}.DisplayOps.scalebar = eval(default_Dopts{6});
    SR{handles.gui_number}.DisplayOps.npp = eval(default_Dopts{7});
    SR{handles.gui_number}.DisplayOps.verbose = eval(default_Dopts{8});
    SR{handles.gui_number}.DisplayOps.CorrDrift= eval(default_Dopts{9});
    SR{handles.gui_number}.DisplayOps.clrmap = default_Dopts{10};
    SR{handles.gui_number}.DisplayOps.resolution= newResolution;
    if updateRes
        ImSetup(hObject,eventdata, handles);
    end  
    handles = ImLoad(hObject,eventdata, handles);
    guidata(hObject, handles);
end