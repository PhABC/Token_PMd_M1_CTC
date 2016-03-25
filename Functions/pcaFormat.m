function FR = pcaFormat(nbins,start,stop,Dat,Stim,idxStim)
% Function that will put the data into fomart compabtible 
% with PCA algorithm. 
%
%   This include :
%		+ Alignment
%		+ Binning
%		+ concatenation
%		+ Averaging over trials

logi_minCom = abs(Dat.commit)>=1;	% Excludes commitment earlier than 'start' or no commit
logi_right  = Dat.commit>0;		% Excludes trials where answer is left 

logi = logi_minCom & logi_right; 

dimC = size(Dat.PMd{1});  % Size of cells in each field

%% Data transformation

% Bin parameters
fn = fields(Dat);		% Field names ; last fields should be fields that don't
                        %               containt neural data
                    
for f = 1:length(fn)-2
    
    goodTr  = Dat.(fn{f})(logi);     % Good trials

    FR.(fn{f}) = zeros(dimC(1),nbins,length(Stim.logIdx));

    %% Bin and Alignment 

    % Only taking relevant sections
    goodTr = cellfun( @(X) cutTrial(X,start,stop),goodTr, ...
                      'UniformOutput',false);

    % Binning cells
    goodTr  = cellfun( @(X) binmean(X,nbins),goodTr, ...
                       'UniformOutput',false);
                   
    goodIdx  =  idxStim(logi);
    goodCom  =  Dat.commit(logi);
    goodNTok =  Dat.nbTokens(logi);
  
%% Trial classification
      
    DatC = classTrialCommit(goodTr, Stim, goodIdx,goodNTok);  %wrt to commit
   %DatC =  classTrialStart(goodTr, Stim, goodIdx);           %wrt onset

    for c = 1:length(Stim.logIdx)              
       if ~isempty(DatC{c})
          if ~isempty(DatC{1})
              FR.(fn{f})(:,:,c) = meanTrial(DatC{c});                 
          end
       end
    end
 
    
end

FR.Idx      = goodIdx;
FR.Com      = goodCom;
FR.nbTokens = goodNTok; 



function FR = meanTrial(D)
% Mean of all trials in cell
stackD  = cat(3,D{:});
FR      = nanmean(stackD,3);


		 
function D = classTrialCommit(Tr, Stim, Idx, nbTokens)
% Will classify trials in respective category based on commitment time

%% Classification Definition
% Defining the rules for each category with respect to commitment

%Easy trials
    % Last 7 tokens if at least 4 are > 0.5, including most recent one
    eLogi = [ .5, .5, .5, .5, .5, .5, .5];  % Bigger than
%Misleading trials      
    % Last 7 tokens if at least 3 are < 0.5 with most recent one > 0.5
    mLogi = [ .5, .5, .5, .5, .5, .5,  0];  % Smaller than
%Ambiguous trials
    % Last 7 tokens if at least 3 are == 0.5 with most recent >= 0.5
    aLogi = [ .5, .5, .5, .5, .5, .5, .5 ];  % Equal to

%% Classification 
% NOTE :
%   Since a trial might be classified as both misleading and ambiguous,
%   ( e.g. prob = 0.35, 0.5, 0.3, 0.5, 0.25, 0.5, 1 ), misleading 
%    classification will be prioritized. 

%   Since a trial might be classified as both ambiguous and easy
%   ( e.g. prob = 0.6,  0.5, 0.6, 0.5, 0.75, 0.5, 1 ), ambiguous 
%   classification will be prioritized . 

%   Since a trial might be classified as both misleading and easy
%   ( e.g. prob = 0.2,  0.27, 0.37, 0.5, 0.6, 0.77, .9 ), misleading 
%   classification will be prioritized .
    
nTrials = length(Tr); % Size of each field

D = cell(4,1);

for t = 1:nTrials
   
    startTok = nbTokens(t)-6; 
    if startTok <= 0; startTok = 1; end  %look at past seven if at least 7
    
    % Contains last 7 (or less) token probabilities
    prob7 = Stim.probR(Idx(t),startTok:nbTokens(t)); 
    nprob = length(prob7);
    
    %Misleading  trials
    if  sum(prob7 < mLogi(8-nprob:end)) >= 3 && prob7(end) > 0.5        
       
        D{2} = vertcat(D{2},Tr(t));
        
    %Ambiguous trials
    elseif sum(prob7 == aLogi(8-nprob:end)) >= 3 && prob7(end) >= 0.5   
        
        D{3} = vertcat(D{3},Tr(t));
    
    %Easy trials
    elseif sum(prob7 > eLogi(8-nprob:end)) >= 3 && prob7(end) > 0.5
        
        D{1} = vertcat(D{1},Tr(t));
    
    %Other trials
    else 
   
        D{4} = vertcat(D{4},Tr(t));  
   
    end
    
end

      

