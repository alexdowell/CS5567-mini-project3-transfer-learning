% This Matlab code demonstrates how to perform image classification using transfer learning
% with AlexNet or VGG19 deep learning networks.

% Unzip the contents of 'archive.zip' (from Kaggle) into a folder named 'archive'
unzip('archive.zip', 'archive');

% Create an ImageDatastore object 'imds' that reads image data from the 'archive' folder
% 'IncludeSubfolders' is set to true to include images in subfolders
% 'LabelSource' is set to 'foldernames' to use folder names as labels for images
% 'ReadFcn' is set to use the customReadFcn defined at the end of the script
imds = imageDatastore('archive', ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames', ...
    'ReadFcn', @customReadFcn); 

% Split the image datastore into 70% training and 30% validation datastores
[imdsTrain,imdsValidation] = splitEachLabel(imds,0.7,'randomized');

% Calculate the number of training images
numTrainImages = numel(imdsTrain.Labels);

% Display a random sample of 25 training images in a 5x5 grid
idx = randperm(numTrainImages,25);
figure
for i = 1:25 
    subplot(5,5,i)
    I = readimage(imdsTrain,idx(i));
    imshow(I)
end

% Load the pre-trained AlexNet or VGG19 network
%net = alexnet;
net = vgg19;
% Analyze the network structure
analyzeNetwork(net)

% Get the input size of the network
inputSize = net.Layers(1).InputSize

% Remove the last three layers of the network to prepare for transfer learning
layersTransfer = net.Layers(1:end-3);

% Calculate the number of unique classes in the training data
numClasses = numel(categories(imdsTrain.Labels))

% Define the new layers for transfer learning
layers = [
    layersTransfer
    fullyConnectedLayer(numClasses,'WeightLearnRateFactor',20,'BiasLearnRateFactor',20)
    softmaxLayer
    classificationLayer];

% Define the parameters for image augmentation
pixelRange = [-30 30];
imageAugmenter = imageDataAugmenter( ...
    'RandXReflection',true, ...
    'RandXTranslation',pixelRange, ...
    'RandYTranslation',pixelRange);

% Create augmented image datastores for training and validation
augimdsTrain = augmentedImageDatastore(inputSize(1:2),imdsTrain, ...
    'DataAugmentation',imageAugmenter);
augimdsValidation = augmentedImageDatastore(inputSize(1:2),imdsValidation);

% Define the training options
options = trainingOptions('sgdm', ...
    'MiniBatchSize',10, ...
    'MaxEpochs',6, ...
    'InitialLearnRate',1e-4, ...
    'Shuffle','every-epoch', ...
    'ValidationData',augimdsValidation, ...
    'ValidationFrequency',3, ...
    'Verbose',false, ...
    'Plots','training-progress');

% Train the network using transfer learning
netTransfer = trainNetwork(augimdsTrain,layers,options);

% Classify the validation images using the trained network
[YPred,scores] = classify(netTransfer,augimdsValidation);

% Display a random sample of 4 validation images with their predicted labels
idx = randperm(numel(imdsValidation.Files),4);
figure
for i = 1:4
    subplot(2,2,i)
    I = readimage(imdsValidation,idx(i));
    imshow(I)
    label = YPred(idx(i));
    title(string(label));
end

% Calculate the accuracy of the predictions by comparing them to the true labels
YValidation = imdsValidation.Labels;
accuracy = mean(YPred == YValidation)

% Define a custom read function to convert grayscale images to rgb images
function data = customReadFcn(filename)
    data = imread(filename);
    data = cat(3, data, data, data);
end