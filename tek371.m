function [traces] = tek371(fileName, outputType)
%TEK371 curve tracer binary file conversion utility
%
%   Reads the binary data from CURVE.CXX files.
%
%   TEK317() shows the file dialog and plots the iv data.
%   TEK317() also returns the data points in a structure 
%   containing generator voltage/current and curve data points.
%
%   TEK317('FILENAME') reads the specific data file.
%
%   TEK317('FILENAME','FORMAT') saves the iv curves in a file 
%   in the format specified by FORMAT. Valid options for FORMAT 
%   are the same as SAVEAS command formats and additionally: 
%
%   - NONE to get just the data structure without displaying the figure.
%
%   - CSV to get the CSV file instead of a plot

%% open file

if nargin < 1 || isempty(fileName)
  [fileName, pathName] = uigetfile('*.*', 'MultiSelect', 'on'); % get files from UI if no file specified
else
  [pathName,fileBaseName,fileExt] = fileparts(fileName); % split given file path
  fileName = [fileBaseName fileExt];
end

if nargin < 2
  outputType = 'plot'; % if no format specified just plot the data
end

if iscell(fileName)
  nFiles = length(fileName);
elseif fileName ~= 0
  nFiles = 1;
  fileName = cellstr(fileName);
else
  nFiles = 0; % error instead! **********
end

%% loop over each file

for iFile = 1:nFiles
  %% open file
  
  fid = fopen(fullfile(pathName,fileName{iFile}));

  %% parse header
  
  fseek(fid, 5,-1); noOfTraces = fread(fid,1,'uint8'); % no. of traces
  
  [horizontalScale, horizontalScaleUnit] = read_binary_371A(fid, 34);
  [  verticalScale,   verticalScaleUnit] = read_binary_371A(fid, 42);
  [       gateStep,        gateStepUnit] = read_binary_371A(fid, 50);
  [    gateInitial,     gateInitialUnit] = read_binary_371A(fid, 58);
  
  %% parse data
  
  fseek(fid, 16*8,-1); % beginning of data
  
  for nTrace = 1:noOfTraces
    traces(nTrace) = struct('voltage',[],'current',[],'gate',[], 'gateUnit',[]); %#ok<AGROW>
  end
  
  for nTrace = 1:noOfTraces
    traces(nTrace).gate = gateInitial + gateStep*(nTrace-1);
    traces(nTrace).gateUnit = gateInitialUnit;
    
    for idx=1:floor(255/noOfTraces)
      data = fread(fid,4,'uint8')'; % read binary data
      
      voltage = (data(1)*256+data(2))/100*horizontalScale;
      current = (data(3)*256+data(4))/100*verticalScale;
      
      traces(nTrace).voltage = [traces(nTrace).voltage; voltage];
      traces(nTrace).current = [traces(nTrace).current; current];
    end
  end
  
  %% close file
  
  fclose(fid);
  
  %% output
  [~,fileNameWithoutExtension,~] = fileparts(fileName{iFile});
  
  switch(outputType)
    case {'ai','bmp','emf','fig','jpg','m','pbm','pcx','pdf','pgm','png','ppm','tif'}
      hFig = plotoutput(traces,horizontalScale,verticalScale);
      saveas(hFig,fullfile(pathName,fileNameWithoutExtension),outputType)
      close(hFig)
    case {'plot'}
      hFig = plotoutput(traces,horizontalScale,verticalScale);
      set(hFig,'visible','on');
    case {'csv'}
      csvFileName = [fullfile(pathName,fileNameWithoutExtension) '.csv'];
      delete(csvFileName)
      if ~isempty(traces(1).gate)
        gateUnits = traces(1).gateUnit;
        if strcmp(gateUnits(end),'V')
          appendstringtofile(csvFileName, '[Vgs]')
        else
          appendstringtofile(csvFileName, '[Ib]')
        end
        dlmwrite(csvFileName, interlace([traces.gate],NaN(1,numel([traces.gate]))),'-append')
        removenanstring(csvFileName);
        appendstringtofile(csvFileName, '[Data]')
      end
      dlmwrite(csvFileName, interlace([traces.voltage],[traces.current]),'-append')
  end
  
  clear traces
end

%% plot traces

  function [hFig] = plotoutput(traces,horizontalScale,verticalScale)
    hFig = figure('visible','off');
    hPlot = plot([traces.voltage], [traces.current]);
    axis([0 10*horizontalScale 0 10*verticalScale])
    
    xlabel('Voltage [V]')
    ylabel('Current [A]')
    
    if ~isempty(traces(1).gate) % generate only if step generator was on
      gateLegend = cellstr(num2str([traces.gate]'));
      legendOrder = numel(traces):-1:1; % reverse order -> lowest gate at bottom
      legend(hPlot(legendOrder),gateLegend(legendOrder),'Location','SouthEast')
      legend boxoff
    end
  end

%% decodes binary data from 371A curve tracer

  function [scale, unit] = read_binary_371A(fid, where)
    fseek(fid, where,-1); % beggining of data
    value = fread(fid,6      ,'uint8=>char'); % horizontal value/div    100
    voltsPerDiv = str2double(value');
    
    scale = fread(fid,1      ,'uint8=>char'); % horizontal scale m/-    m
    
    switch scale
      case 'm'
        scale = voltsPerDiv*1e-3;
      case 'k'
        scale = voltsPerDiv*1e3;
      otherwise
        scale = voltsPerDiv;
    end
    
    unit = fread(fid,1      ,'uint8=>char'); % horizontal unit          V
  end

  function [AB] = interlace(A,B)
    nColumns = size(A,1);
    AB = reshape([A;B],nColumns,[]);
  end

  function appendstringtofile(fileName, stringToAppend)
    fid = fopen(fileName,'a');
    fprintf(fid,[stringToAppend '\n']);
    fclose(fid);
  end

  function removenanstring(csvFileName)
    fid = fopen(csvFileName,'r');
    f = fread(fid,'*char')';
    fclose(fid);
    f = strrep(f,'nan','');
    f = strrep(f,'NaN','');
    fid = fopen(csvFileName,'w');
    fprintf(fid,'%s',f);
    fclose(fid);
  end
end