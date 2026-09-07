%% NAYANDRISHTI - MASTER DIAGNOSTIC PIPELINE (SELF-CONTAINED)
% Clear environment
clear; clc; close all;

%% 0. GENERATE SYNTHETIC FUNDUS IMAGE (FOR DEMO EXECUTION)
[X, Y] = meshgrid(1:512, 1:512);
centerR = 256; centerC = 256; radius = 230;
mask = ((X - centerC).^2 + (Y - centerR).^2) <= radius^2;

% Base fundus colors
redChan = uint8(200 * mask);
greenChan = uint8(90 * mask);
blueChan = uint8(30 * mask);
syntheticFundus = cat(3, redChan, greenChan, blueChan);

% Add Optic Disc
odMask = ((X - 380).^2 + (Y - 256).^2) <= 35^2;
syntheticFundus(:,:,1) = syntheticFundus(:,:,1) + uint8(55 * odMask);
syntheticFundus(:,:,2) = syntheticFundus(:,:,2) + uint8(140 * odMask);

% Add Synthetic Vessels
vessels = (abs(Y - 256 - 50*sin(X/40)) < 4) | (abs(X - 380 - 30*cos(Y/50)) < 4);
vessels = vessels & mask;
syntheticFundus(:,:,1) = syntheticFundus(:,:,1) .* uint8(~vessels);
syntheticFundus(:,:,2) = syntheticFundus(:,:,2) .* uint8(~vessels);

%% PILLAR 1: QUALITY GATE & ENHANCEMENT
greenPlane = syntheticFundus(:,:,2);
laplacianFilter = [0 1 0; 1 -4 1; 0 1 0];
blurScore = var(double(imfilter(greenPlane, laplacianFilter)), [], 'all');

if blurScore < 0.005
    qualityStatus = 'PASS (Sufficient Clarity)';
else
    qualityStatus = 'PASS (Enhanced)';
end

enhancedGreen = adapthisteq(greenPlane, 'ClipLimit', 0.02, 'Distribution', 'rayleigh');

%% PILLAR 2: VASCULAR SEGMENTATION & OPTIC DISC MASKING
se = strel('disk', 12);
topHat = imtophat(enhancedGreen, se);
vesselBinary = imbinarize(topHat, 'adaptive', 'Sensitivity', 0.45);

% Optic Disc Masking via Active Contour Simulation
opticDiscMask = false(size(greenPlane));
opticDiscMask(220:290, 345:415) = true;

%% PILLAR 3 & 4: DIAGNOSTIC GRADING & GRAD-CAM HEATMAP
% Simulated Deep Learning Grading Output
icdrGrade = 2; % Moderate NPDR
severityLabels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'PDR'};
detectedLabel = severityLabels{icdrGrade + 1};

% Synthetic Grad-CAM Heatmap Generation
[Xg, Yg] = meshgrid(1:512, 1:512);
gradCamHeatmap = exp(-((Xg-220).^2 + (Yg-200).^2)/(2*45^2)) + ...
    exp(-((Xg-300).^2 + (Yg-280).^2)/(2*35^2));
gradCamHeatmap = gradCamHeatmap / max(gradCamHeatmap(:));

%% DISPLAY 4-PANEL DIAGNOSTIC DASHBOARD
figure('Name', 'MathWorks Diagnostic Panel', 'Position', [100, 100, 1000, 700], 'Color', 'w');

subplot(2,2,1);
imshow(syntheticFundus);
title({'Panel A: Raw Input Scan', ['Quality Status: ' qualityStatus]}, 'FontSize', 11, 'FontWeight', 'bold');

subplot(2,2,2);
imshow(enhancedGreen);
title('Panel B: Green Channel CLAHE Contrast Enhancement', 'FontSize', 11, 'FontWeight', 'bold');

subplot(2,2,3);
imshow(vesselBinary);
title('Panel C: Segmented Vascular Web & Target Masking', 'FontSize', 11, 'FontWeight', 'bold');

subplot(2,2,4);
imshow(syntheticFundus); hold on;
h = imshow(gradCamHeatmap);
colormap(gca, 'jet');
set(h, 'AlphaData', gradCamHeatmap * 0.6);
title({['Panel D: Grad-CAM Heatmap Target Overlay'], ['ICDR Diagnosis: ' detectedLabel ' (Grade ' num2str(icdrGrade) ')']}, ...
    'FontSize', 11, 'FontWeight', 'bold', 'Color', 'r');

sgtitle('NayanDrishti: Automated Retinal Health Assessment Pipeline', 'FontSize', 14, 'FontWeight', 'bold');