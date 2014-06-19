function createSegImages(stackFileType,varargin)
%% ========================================================================
%   Name:       createSegImages.m
%   Version:    2.2, 3 July 2012
%   Author:     Allison Wu
%   Command:    createSegImages(stackFileType,reSize*)
%   Description:
%       - Creates "dye_posSuffix_segStacks.mat" files for each position and each channel
%       - segStacks.mat files can be used for spot analysis and nuclei counting
%       - Each segStacks.mat file has two cell arrays.
%         One is segStacks,which saves all the segmented image stacks for each worm in each cell.
%         The other is segMasks, which saves the mask matrix for each worm in each cell.
%       - reSize: the scale you want to resize your image. (if it's 0-1, it
%       shrinks the image.)
%
%   Files required:     stk or tiff image stacks, segmenttrans_{stackSuffix}.mat, metaInfo.mat (for tif)
%                       File name examples: cy5_Pos0.tif,
%                                           segmenttrans_Pos0.mat
%   Files generated:    {dye}_{stackSuffix}_segStacks.mat

%   Updates: 
%       - 2012 Aug. 6th, adding the input variable for users to resize the images.   
%       - 2013 Apr. 11th, change the way it finds the dye names, making it
%       more generic.
%       - 2013 Apr. 16th, replace readTiffStack with loadtiff to avoid
%       imread problem on Mac.
%
%   Attribution: Wu, AC-Y and SA Rifkin. spotFinding Suite version 2.5, 2013 [journal citation TBA]
%   License: Creative Commons Attribution-ShareAlike 3.0 United States, http://creativecommons.org/licenses/by-sa/3.0/us/
%   Website: http://www.biology.ucsd.edu/labs/rifkin/software/spotFindingSuite
%   Email for comments, questions, bugs, requests:  Allison Wu < dblue0406 at gmail dot com >, Scott Rifkin < sarifkin at ucsd dot edu >
%
%% ========================================================================

% stackFileType: 'stk', 'tif'

% Determine filetype and find available color channels first
disp(['Stack file type is: ' stackFileType]);
disp('Determine the channels available : ')
if strcmp(stackFileType,'stk')
    initialnumber = '001';
    d = dir(['*' initialnumber '*.stk']);
    currcolor = 1;
    for i = 1:length(d)
        tmp = strrep(d(i).name,[initialnumber '.stk'],'');
        tmp = strrep(tmp,'_','');
        if ~sum(strcmp(tmp,{'segment','thumbs','gfp'}))  %these are "special"
            dye{currcolor} = tmp;
            currcolor = currcolor+1;
        end;
    end;
    
elseif strcmp(stackFileType,'tif') || strcmp(stackFileType,'tiff')
    d = dir('*_Pos*.tif');
    for k=1:length(d)
        nameSplit=regexp(d(k).name,'_','split');
        tmp{k}=nameSplit{1};
    end
    tmp=unique(tmp);
    
    j = 1;
    while j<=length(tmp) && ~sum(strcmpi(tmp(j),{'segment','thumbs','gfp','trans'}))  %these are "special"
            dye{j} = tmp{j};
            j = j+1;
    end;    
end;

dye=sort(dye);
disp(dye);


stacks=dir('segmenttrans*');
stackSize=zeros(length(dye),3);

if ~isempty(varargin)
    reSize=varargin{1};
else
    reSize=1;
end


for i=1:length(stacks)
    for di=1:length(dye)
        
        stackName=regexprep(stacks(i).name,'_','\.');
        nameSplit=regexp(stackName,'\.','split');
        nameSplit=nameSplit(~cellfun('isempty',nameSplit));
        stackSuffix=nameSplit{2};
        segStackFileName=[dye{di} '_' stackSuffix '_SegStacks.mat'];
        disp(stackSuffix);
        load(['segmenttrans_' stackSuffix '.mat'])
        if ~exist(segStackFileName,'file') %cy5_Pos0_segStacks.mat
            fprintf('Creating %s segStacks of %s ....\n',dye{di},stackSuffix);
            tic
            fprintf('Dye %s: \n',dye{di})
            segStacks=cell(length(currpolys),1);
            segMasks=cell(length(currpolys),1);
            if strcmp(stackFileType,'stk')
                if exist([dye{di} stackSuffix '.stk'],'file')
                    stackInfo=readmm([dye{di} stackSuffix '.stk']);
                    stack=stackInfo.imagedata;
                    clear stackInfo
                    stack=double(stack);
                else
                    fprintf('Failed to find the file %s .', [dye{di} stackSuffix '.stk'])
                end
            elseif strcmp(stackFileType,'tif') || strcmp(stackFileType,'tiff')
                if exist([dye{di} '_' stackSuffix '.tif'],'file')
                    stack=double(tiffLoaderPureMatlab([dye{di} '_' stackSuffix '.tif']));
                elseif exist([dye{di} '__' stackSuffix '.tif'],'file')
                    stack=tiffLoaderPureMatlab([dye{di} '__' stackSuffix '.tif']);
                else
                    fprintf('Failed to find the file %s .', [dye{di} '_' stackSuffix '.tif'])
                end
            end
            
            for wi=1:length(currpolys)
                bb=regionprops(double(currpolys{wi}),'BoundingBox');
                wormMask=imresize(imcrop(currpolys{wi},bb.BoundingBox),reSize);
                wormImage=zeros([size(wormMask), size(stack,3)]);
                %fprintf('Worm %d : ', wi)
                segMasks{wi}=wormMask;
                
                for zi=1:size(stack,3)
                    wormImage(:,:,zi)=imresize(double(imcrop(stack(:,:,zi),bb.BoundingBox)),reSize).*wormMask;
                    wil=wormImage(:,:,zi);
                    wil=wil(wil>0);%don't change to their suggested equivalent...doesn't work
                    pwil=max(prctile(wil,20));
                    %disp([num2str(zi) ' ' num2str(pwil)]);
                    wormImage(:,:,zi)=wormImage(:,:,zi)/pwil;%takes care of out of focus ones
                    clear('wil');
                end
                segStacks{wi}=wormImage;
                clear wormImage
                fprintf('%g%% ', wi/length(currpolys)*100)
            end
            
            save(fullfile(pwd,segStackFileName),'segStacks','segMasks')
            fprintf('\n')
            tElapsed=toc;
            tElapsed=tElapsed/60;
            fprintf('For %s in position %s , it took %g minutes. \n', dye{di}, stackSuffix, tElapsed)
            
            clear stack
            
            
        else
            fprintf('%s segStacks of %s is already saved.\n', dye{di},stackSuffix)
            
        end
        fprintf('\n')
        
    end
end
%stack=loadtiff(['dapi' stackSuffix '.tif'],1,stackSize(di,3));
%stack=double(stack);
end