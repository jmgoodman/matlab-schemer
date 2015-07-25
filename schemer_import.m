%SCHEMER_IMPORT Import a MATLAB color scheme
%   SCHEMER_IMPORT() with no input will prompt the user to locate the
%   color theme source file via the GUI.
%   
%   SCHEMER_IMPORT(FILENAME) imports the color scheme options given in
%   the file FILENAME. 
%   
%   SCHEMER_IMPORT(FILENAME, INCLUDEBOOLS) can control whether boolean
%   preferences are included in import (default: FALSE). If INCLUDEBOOLS
%   is set to true, boolean preference options such as whether to
%   highlight autofixable errors, or to show variables with shared scope in
%   a different colour will also be overridden, should they be set in the
%   input file.
%   
%   SCHEMER_IMPORT(INCLUDEBOOLS, FILENAME), with a boolean or numeric input
%   followed by a string input, will also work as above because the input
%   order is reversible.
%   
%   SCHEMER_IMPORT(INCLUDEBOOLS) with a single boolean input will open the
%   GUI to pick the file, and will load boolean preferences in accordance
%   with INCLUDEBOOLS.
%   
%   RET = SCHEMER_IMPORT(...) returns 1 on success, 0 on user
%   cancellation at input file selection screen, -1 on fopen error, and -2
%   on any other error.
%   
%   NOTE:
%   The file to import can either be color scheme file as generated by
%   SCHEMER_EXPORT, or an entire MATLAB preferences file such as the file
%   you will find located at FULLFILE(PREFDIR,'matlab.prf'). This could be
%   a MATLAB preferences file taken from a different computer or previous
%   MATLAB installation. However, if you are importing from a matlab.prf
%   file instead of a color scheme .prf file you should be aware that any
%   colour preferences which have been left as the defaults on preference
%   panels which the user has not visited on the origin system of the
%   matlab.prf file will not be present in the file, and hence not updated
%   on import.
%   By default, MATLAB preference options which will be overwritten by
%   SCHEMER_IMPORT are:
%   - All settings in the Color pane of Preferencs
%   - All colour settings in the Color > Programming Tools pane, but no
%     checkboxes
%   - From Editor/Debugger > Display pane, the following:
%      - Highlight current line (colour, but not whether to)
%      - Right-hand text limit (colour and thickness, but not on/off)
%   - From Editor/Debugger > Language, the syntax highlighting colours for
%     each language.
%   
%   Once the current colour preferences are overridden they cannot be
%   undone, so it is recommended that you export your current preferences
%   with SCHEMER_EXPORT before importing a new theme if you think you
%   may wish to revert.
%   
%   This is not necessary if you are using the default MATLAB color scheme
%   which ships with the installation, as SCHEMER comes with a copy of the
%   MATLAB default color scheme (default.prf).
%   
%   If you wish to revert to the default MATLAB color scheme, it is
%   recommended you import the file default.prf included in this
%   package. This will reset Editor/Debugger>Display colours, colours for
%   syntax highlighting in additional languages, as well as the colours set
%   in the Colors pane. You can also revert the colors by clicking
%   "Restore Default Colors" in the MATLAB preference panel interface, but
%   this will be less effective because there are several panels which set
%   syntax colours and not all of them have a restore button.
%   
%   For more details on how to get and set MATLAB preferences with
%   commands, see the following URL.
%   http://undocumentedmatlab.com/blog/changing-system-preferences-programmatically/
%   
%   See also SCHEMER_EXPORT, PREFDIR.

% Copyright (c) 2013, Scott Lowe
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.

% Known issues:
% 
% 1. Text colour of automatically highlighted variables does not change
%    colour immediately. This is an issue with matlab; if you change the main
%    text colour in the preferences pane, highlighted variables will still
%    have the old text colour until matlab is restarted.
%    
% 2. Java exception is thrown when first trying to update the setting
%    Editor.VariableHighlighting.Color. This only happens the first
%    time SCHEMER_IMPORT is run, so the current fix is to catch the error
%    and then try again. However, it might be possible for other Java
%    exceptions get thrown under other mysterious circumstances, which could 
%    cause the function to fail.

function varargout = schemer_import(fname, inc_bools)

% ------------------------ Parameters -------------------------------------
SCHEMER_VERSION = 'v1.2.5';

% ------------------------ Input handling ---------------------------------
% ------------------------ Default inputs ---------------------------------
if nargin<2
    inc_bools = false; % Default off, so only override extra options if intended
end
if nargin<1
    fname = []; % Ask user to select file
end
% Input switching
if nargin>=1 && ~ischar(fname) && ~isempty(fname)
    if ~islogical(fname) && ~isnumeric(fname)
        error('Invalid input argument 1');
    end
    if nargin==1
        % First input omitted
        inc_bools = fname;
        fname = [];
    elseif ischar(inc_bools)
        % Inputs switched
        tmp = fname;
        fname = inc_bools;
        inc_bools = tmp;
        clear tmp;
    else
        error('Invalid combination of inputs');
    end
end

% ------------------------ Check for file ---------------------------------
filefilt = ...
   {'*.prf;*.txt', 'Text and pref files (*.prf, *.txt)'; ...
    '*'          ,  'All Files'                        };

if ~isempty(fname)
    if ~exist(fname,'file')
        error('Specified file does not exist');
    end
else
    % Dialog asking for input filename
    % Need to make this dialogue include .txt by default, at least
    [filename, pathname] = uigetfile(filefilt);
    % End if user cancels
    if isequal(filename,0);
        if nargout>0; varargout{1} = 0; end;
        return;
    end
    fname = fullfile(pathname,filename);
end

% ------------------------ Catch block ------------------------------------
% Somewhat inexplicably, a Java exception is thrown the first time we try
% to set 'Editor.VariableHighlighting.Color'.
% But if we try again immediately, it can be set without any problems.
% The issue is very consistent.
% The solution is to try to set this colour along with all the others,
% catch the exception when it occurs, and then attempt to set all the
% preferences again.
try
    [varargout{1:nargout}] = main(fname, inc_bools);
catch ME
    if ~strcmp(ME.identifier,'MATLAB:Java:GenericException');
        rethrow(ME);
    end
    % disp('Threw and ignored a Java exception. Retrying.');
    [varargout{1:nargout}] = main(fname, inc_bools);
end

end

% ======================== Main code ======================================
function varargout = main(fname, inc_bools)

% ------------------------ Parameters -------------------------------------
names_boolean = {                                   ...
    'ColorsUseSystem'                               ... % Color:    Desktop:    Use system colors
};
names_boolextra = {                                 ...
    'ColorsUseMLintAutoFixBackground'               ... % Color>PT: Analyser:   autofix highlight
    'Editor.VariableHighlighting.Automatic'         ... % Color>PT: Var&fn:     auto highlight
    'Editor.NonlocalVariableHighlighting'           ... % Color>PT: Var&fn:     with shared scope
    'EditorCodepadHighVisible'                      ... % Color>PT: CellDisp:   highlight cells
    'EditorCodeBlockDividers'                       ... % Color>PT: CellDisp:   show lines between cells
    'Editorhighlight-caret-row-boolean'             ... % Editor>Display:       Highlight current line
    'EditorRightTextLineVisible'                    ... % Editor>Display:       Show Right-hand text limit
};
names_integer = {                                   ...
    'EditorRightTextLimitLineWidth'                 ... % Editor>Display:       Right-hand text limit Width
};
names_color = { ...
    'ColorsText'                                        , ... % Color:    Desktop:    main text colour
        ''                                                  ; ...
    'ColorsBackground'                                  , ... % Color:    Desktop:    main background
        ''                                                  ; ...
    'Colors_M_Errors'                                   , ... % Color:    Syntax:     errors
        -65536                                              ; ...
    'Colors_M_Warnings'                                 , ... % Color>PT: Analyser:   warnings
        -27648                                              ; ...
    'Colors_M_Keywords'                                 , ... % Color:    Syntax:     keywords
        'ColorsText'                                        ; ...
    'Colors_M_Comments'                                 , ... % Color:    Syntax:     comments
        {'ColorsText','ColorsBackground'}                   ; ...
    'Colors_M_Strings'                                  , ... % Color:    Syntax:     strings
        'ColorsText'                                        ; ...
    'Colors_M_UnterminatedStrings'                      , ... % Color:    Syntax:     unterminated strings
        'Colors_M_Errors'                                   ; ...
    'Colors_M_SystemCommands'                           , ... % Color:    Syntax:     system commands
        'Colors_M_Keywords'                                 ; ...
    'Colors_HTML_HTMLLinks'                             , ... % Color:    Other:      hyperlinks
        'ColorsText'                                        ; ...
    'Color_CmdWinWarnings'                              , ... % Color:    Other:      Warning messages
        'Colors_M_Warnings'                                 ; ...
    'Color_CmdWinErrors'                                , ... % Color:    Other:      Error messages
        'Colors_M_Errors'                                   ; ...
    'ColorsMLintAutoFixBackground'                      , ... % Color>PT: Analyser:   autofix
        'ColorsBackground'                                  ; ...
    'Editor.VariableHighlighting.Color'                 , ... % Color>PT: Var&fn:     highlight
        'ColorsBackground'                                  ; ...
    'Editor.NonlocalVariableHighlighting.TextColor'     , ... % Color>PT: Var&fn:     with shared scope
        'ColorsText'                                        ; ...
    'Editorhighlight-lines'                             , ... % Color>PT: CellDisp:   highlight
        'ColorsBackground'                                  ; ...
    'Editorhighlight-caret-row-boolean-color'           , ... % Editor>Display:       Highlight current line Color
        'ColorsBackground'                                  ; ...
    'EditorRightTextLimitLineColor'                     , ... % Editor>Display:       Right-hand text limit line Color
        'ColorsText'                                        ; ...
    'Editor.Language.MuPAD.Color.keyword'               , ... % MuPAD: Keywords
        'Colors_M_Keywords'                                 ; ...
    'Editor.Language.MuPAD.Color.operator'              , ... % MuPAD: Operators
        'Colors_M_SystemCommands'                           ; ...
    'Editor.Language.MuPAD.Color.block-comment'         , ... % MuPAD: Comments
        'Colors_M_Comments'                                 ; ...
    'Editor.Language.MuPAD.Color.option'                , ... % MuPAD: Options
        'Colors_M_UnterminatedStrings'                      ; ...
    'Editor.Language.MuPAD.Color.string'                , ... % MuPAD: Strings
        'Colors_M_Strings'                                  ; ...
    'Editor.Language.MuPAD.Color.function'              , ... % MuPAD: System Functions
        {'Colors_M_Keywords','ColorsBackground'}            ; ...
    'Editor.Language.MuPAD.Color.constant'              , ... % MuPAD: Constants
        'Editor.NonlocalVariableHighlighting.TextColor'     ; ...
    'Editor.Language.TLC.Color.Colors_M_SystemCommands' , ... % TLC: Commands
        'Colors_M_Keywords'                                 ; ...
    'Editor.Language.TLC.Color.Colors_M_Keywords'       , ... % TLC: Macros
        'Colors_M_SystemCommands'                           ; ...
    'Editor.Language.TLC.Color.Colors_M_Comments'       , ... % TLC: Comments
        'Colors_M_Comments'                                 ; ...
    'Editor.Language.TLC.Color.string-literal'          , ... % TLC: C Strings
        'Colors_M_Strings'                                  ; ...
    'Editor.Language.VRML.Color.keyword'                , ... % VRML: Keywords
        'Colors_M_Keywords'                                 ; ...
    'Editor.Language.VRML.Color.node-keyword'           , ... % VRML: Node types
        'Colors_HTML_HTMLLinks'                             ; ...
    'Editor.Language.VRML.Color.field-keyword'          , ... % VRML: Fields
        'Editor.NonlocalVariableHighlighting.TextColor'     ; ...
    'Editor.Language.VRML.Color.data-type-keyword'      , ... % VRML: Data types
        'Colors_M_UnterminatedStrings'                      ; ...
    'Editor.Language.VRML.Color.terminal-symbol'        , ... % VRML: Terminal symbols
        'Colors_M_SystemCommands'                           ; ...
    'Editor.Language.VRML.Color.comment'                , ... % VRML: Comments
        'Colors_M_Comments'                                 ; ...
    'Editor.Language.VRML.Color.string'                 , ... % VRML: Strings
        'Colors_M_Strings'                                  ; ...
    'Editor.Language.C.Color.keywords'                  , ... % C/C++: Keywords
        'Colors_M_Keywords'                                 ; ...
    'Editor.Language.C.Color.line-comment'              , ... % C/C++: Comments
        'Colors_M_Comments'                                 ; ...
    'Editor.Language.C.Color.string-literal'            , ... % C/C++: Strings
        'Colors_M_Strings'                                  ; ...
    'Editor.Language.C.Color.preprocessor'              , ... % C/C++: Preprocessor
        'Colors_M_SystemCommands'                           ; ...
    'Editor.Language.C.Color.char-literal'              , ... % C/C++: Characters
        'Colors_M_UnterminatedStrings'                      ; ...
    'Editor.Language.C.Color.errors'                    , ... % C/C++: Bad characters
        'Colors_M_Errors'                                   ; ...
    'Editor.Language.Java.Color.keywords'               , ... % Java: Keywords
        'Colors_M_Keywords'                                 ; ...
    'Editor.Language.Java.Color.line-comment'           , ... % Java: Comments
        'Colors_M_Comments'                                 ; ...
    'Editor.Language.Java.Color.string-literal'         , ... % Java: Strings
        'Colors_M_Strings'                                  ; ...
    'Editor.Language.Java.Color.char-literal'           , ... % Java: Characters
        'Colors_M_UnterminatedStrings'                      ; ...
    'Editor.Language.VHDL.Color.Colors_M_Keywords'      , ... % VHDL: Keywords
        'Colors_M_Keywords'                                 ; ...
    'Editor.Language.VHDL.Color.operator'               , ... % VHDL: Operators
        'Colors_M_SystemCommands'                           ; ...
    'Editor.Language.VHDL.Color.Colors_M_Comments'      , ... % VHDL: Comments
        'Colors_M_Comments'                                 ; ...
    'Editor.Language.VHDL.Color.string-literal'         , ... % VHDL: Strings
        'Colors_M_Strings'                                  ; ...
    'Editor.Language.Verilog.Color.Colors_M_Keywords'   , ... % Verilog: Keywords
        'Colors_M_Keywords'                                 ; ...
    'Editor.Language.Verilog.Color.operator'            , ... % Verilog: Operators
        'Colors_M_SystemCommands'                           ; ...
    'Editor.Language.Verilog.Color.Colors_M_Comments'   , ... % Verilog: Comments
        'Colors_M_Comments'                                 ; ...
    'Editor.Language.Verilog.Color.string-literal'      , ... % Verilog: Strings
        'Colors_M_Strings'                                  ; ...
    'Editor.Language.XML.Color.error'                   , ... % XML: Error
        'Colors_M_Errors'                                   ; ...
    'Editor.Language.XML.Color.tag'                     , ... % XML: Tag
        'Colors_M_Keywords'                                 ; ...
    'Editor.Language.XML.Color.attribute'               , ... % XML: Attribute name
        'Colors_M_UnterminatedStrings'                      ; ...
    'Editor.Language.XML.Color.operator'                , ... % XML: Operator
        'Colors_M_SystemCommands'                           ; ...
    'Editor.Language.XML.Color.value'                   , ... % XML: Attribute value
        'Colors_M_Strings'                                  ; ...
    'Editor.Language.XML.Color.comment'                 , ... % XML: Comment
        'Colors_M_Comments'                                 ; ...
    'Editor.Language.XML.Color.doctype'                 , ... % XML: DOCTYPE declaration
        'Colors_HTML_HTMLLinks'                             ; ...
    'Editor.Language.XML.Color.ref'                     , ... % XML: Character
        'Colors_M_UnterminatedStrings'                      ; ...
    'Editor.Language.XML.Color.pi-content'              , ... % XML: Processing instruction
        'Colors_HTML_HTMLLinks'                             ; ...
    'Editor.Language.XML.Color.cdata-section'           , ... % XML: CDATA section
        'Editor.NonlocalVariableHighlighting.TextColor'     ; ...
};

% 'Editor.Language.Java.method' $ plain / bold / italic

verbose = 0;

% ------------------------ Setup ------------------------------------------
if nargout==0
    varargout = {};
else
    varargout = {-2};
end
if inc_bools
    names_boolean = [names_boolean names_boolextra];
end

% ------------------------ Check file seems okay --------------------------
% Read in the contents of the entire file
flestr = fileread(fname);
% Search for occurances of main text colour
txtprf = regexp(flestr,'\sColorsText=(?<pref>[^#\s]+)\s','names');
if isempty(txtprf)
    error('Text colour not present in colorscheme file:\n%s',fname);
elseif length(txtprf)>1
    error('Text colour defined multiple times in colorscheme file:\n%s',fname);
end
% Search for occurances of main background colour
bkgprf = regexp(flestr,'\sColorsBackground=(?<pref>[^#\s]+)\s','names');
if isempty(bkgprf)
    error('Background colour not present in colorscheme file:\n%s',fname);
elseif length(bkgprf)>1
    error('Background colour defined multiple times in colorscheme file:\n%s',fname);
end
% Make sure the main text and background colours are not exactly the same
if strcmp(txtprf.pref, bkgprf.pref)
    error('Main text and background colours are the same in this file:\n%s',fname);
end

% ------------------------ File stuff -------------------------------------
% Open for read access only
fid = fopen(fname,'r','n');
if isequal(fid,-1);
    if nargout>0; varargout{1} = -1; end;
    return;
end
% Add a cleanup object incase of failure
finishup = onCleanup(@() fclose(fid));

% ------------------------ Read and Write ---------------------------------
% Initialise tracker for unset colours
isColorSet = false(size(names_color,1), 1);
% Loop over prf file
while ~feof(fid)
    % Get one line of preferences/theme file
    l = fgetl(fid);
    
    % Ignore empty lines and lines which begin with #
    if length(l)<1 || strcmp('#',l(1))
        if verbose; disp('Comment'); end;
        continue;
    end
    
    % Look for name pref pair, seperated by '='
    %    Must be at begining of string (hence ^ anchor)
    %    Cannot contain comment marker (#)
    n = regexp(l,'^(?<name>[^=#]+)=(?<pref>[^#]+)','names');
    
    % If no match, continue and scan next line
    if isempty(n)
        if verbose; disp('No match'); end;
        continue;
    end
    
    % Trim whitespace from pref
    n.pref = strtrim(n.pref);
    
    if ismember(n.name,names_boolean)
        % Deal with boolean type
        switch lower(n.pref)
            case 'btrue'
                % Preference is true
                com.mathworks.services.Prefs.setBooleanPref(n.name,1);
                if verbose; fprintf('Set bool true %s\n',n.name); end
            case 'bfalse'
                % Preference is false
                com.mathworks.services.Prefs.setBooleanPref(n.name,0);
                if verbose; fprintf('Set bool false %s\n',n.name); end
            otherwise
                % Shouldn't be anything else
                warning('Bad boolean for %s: %s',n.name,n.pref);
        end
        
    elseif ismember(n.name,names_integer)
        % Deal with integer type
        if ~strcmpi('I',n.pref(1))
            warning('Bad integer pref for %s: %s',n.name,n.pref);
            continue;
        end
        int = str2double(n.pref(2:end));
        com.mathworks.services.Prefs.setIntegerPref(n.name,int);
        if verbose; fprintf('Set integer %d for %s\n',int,n.name); end
   
    elseif ismember(n.name,names_color(:,1))
        % Deal with colour type (final type to consider)
        if ~strcmpi('C',n.pref(1))
            warning('Bad color for %s: %s',n.name,n.pref);
            continue;
        end
        rgb = str2double(n.pref(2:end));
        jc = java.awt.Color(rgb);
        com.mathworks.services.Prefs.setColorPref(n.name, jc);
        com.mathworks.services.ColorPrefs.notifyColorListeners(n.name);
        if verbose
            fprintf('Set color (%3.f, %3.f, %3.f) for %s\n',...
                jc.getRed, jc.getGreen, jc.getBlue, n.name);
        end
        % Note that we have allocated this colour
        [~, idx] = ismember(n.name,names_color(:,1));
        isColorSet(idx) = true;
        
    else
        % Silently ignore irrelevant preferences
        % (This means you can load a whole matlab.pref file and anything not
        % listed above as relevant to the color scheme will be ignored.)
        
    end
    
end

% Check that at least one colour was actually set
if ~any(isColorSet)
    error('Did not find any colour settings in file\n%s', fname);
    if nargout>0; varargout{1} = -2; end;
    return;
end

% For colours which have not been set by the color scheme, we set them from
% a backup
% Get a row vector of indices of all unset colours
unsetColorIndices = find(~isColorSet)';
% Loop over unset colours
for idx=unsetColorIndices
    % Get the backup setting for this colour parameter
    backupVal = names_color{idx,2};
    
    clear jc; % Clear variable
    
    % Switch based on the type of backup
    if isempty(backupVal)
        % No backup is set
        continue;
        
    elseif iscell(backupVal)
        % Backup is one of several methods of which involve refactoring one
        % or more other colours
        % Get an RGB value for the colour through whichever method
        if all(cellfun(@ischar, backupVal))
            % Backup is a list of other names to sample and average
            % Initialise a holding matrix
            RGB = nan(numel(backupVal), 3);
            for i=1:numel(backupVal)
                % Load each of the other colours
                jc = com.mathworks.services.Prefs.getColorPref(backupVal{i});
                % Put the R,G,B values into the holding matrix
                RGB(i,1) = jc.getRed;
                RGB(i,2) = jc.getGreen;
                RGB(i,3) = jc.getBlue;
            end
            % Take the average of each RGB value from the other colours
            RGB = mean(RGB);
            
        elseif length(backupVal)==2
            % Backup is a name of a colour and a scale factor to apply
            jc = com.mathworks.services.Prefs.getColorPref(backupVal{1});
            % Get the R,G,B values
            RGB = [jc.getRed, jc.getGreen, jc.getBlue];
            % Rescale them
            RGB = RGB * backupVal{2};
            
        else
            error('Bad backup cell for %s', names_color{idx,1});
            
        end
        % Turn the RGB value into a Java color object
        % Ensure RGB is integer and does not exceed 255
        RGB = min(255, round(RGB));
        % Convert to a float
        RGB = RGB/255;
        % Make a Java color object for this colour
        jc = java.awt.Color(RGB(1), RGB(2), RGB(3));
        
    elseif ischar(backupVal)
        % The backup colour is a reference to another colour
        % Look up the colour from the backup reference
        jc = com.mathworks.services.Prefs.getColorPref(backupVal);
        
    elseif isnumeric(backupVal) && numel(backupVal)==1
        % The backup colour is a specific colour
        % Make a java color object for this specific colour
        jc = java.awt.Color(backupVal);
        
    else
        error('Bad backup value for %s', names_color{idx,1});
        
    end
    % Assign the neglected colour to be this Java colour object from the
    % backup
    com.mathworks.services.Prefs.setColorPref(names_color{idx,1}, jc);
    com.mathworks.services.ColorPrefs.notifyColorListeners(names_color{idx,1});
    
end

% ------------------------ Tidy up ----------------------------------------
% fclose(fid); % Don't need to close as it will autoclose
if nargout>0; varargout{1} = 1; end;

if inc_bools
    fprintf('Imported color scheme WITH boolean options from\n%s\n',fname);
else
    fprintf('Imported color scheme WITHOUT boolean options from\n%s\n',fname);
end

end
