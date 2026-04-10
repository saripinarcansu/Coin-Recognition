%% ODEV 4 - PARA TESPITI (GERCEK YAZI/TURA ANALIZI)
% Bu programda Turk lirasi madeni paralari tespit edip sayiyoruz
% Ayrica yazi mi tura mi oldugunu da belirliyoruz

clear all; close all; clc;

%% 1. GORUNTU YUKLEME
% Fotografi okuyoruz ve gri tonlamaya ceviriyoruz
img = imread('paralar.jpeg');
gray = rgb2gray(img);
hsv = rgb2hsv(img);
[rows, cols] = size(gray);

%% 2. ARKA PLAN CIKARMA
% Farkli yontemleri birlestirerek tum paralari yakaliyoruz
seviye = graythresh(gray);
bw1 = ~imbinarize(gray, seviye * 0.88);
S = hsv(:,:,2);
bw2 = S > 0.08;
bw3 = ~imbinarize(gray, seviye * 0.80);
bw = bw1 | bw2 | bw3;

% Morfolojik islemler
se = strel('disk', 12);
bw = imclose(bw, se);
bw = imfill(bw, 'holes');
bw = imopen(bw, strel('disk', 6));
bw = bwareaopen(bw, 1500);

%% 3. PARALARI BUL
[labeled, ~] = bwlabel(bw);
stats = regionprops(labeled, 'BoundingBox', 'Centroid', 'Area', 'Eccentricity');

valid_idx = [];
for i = 1:length(stats)
    if stats(i).Eccentricity < 0.55 && stats(i).Area > 1500
        valid_idx = [valid_idx, i];
    end
end

num_coins = length(valid_idx);
fprintf('Tespit edilen para sayisi: %d\n\n', num_coins);

%% 4. CAP VE KONUM HESAPLA
diameters = zeros(num_coins, 1);
centroids = zeros(num_coins, 2);

for i = 1:num_coins
    idx = valid_idx(i);
    bb = stats(idx).BoundingBox;
    diameters(i) = (bb(3) + bb(4)) / 2;
    centroids(i,:) = stats(idx).Centroid;
end

%% 5. PARA SINIFLANDIRMA
max_d = max(diameters);
cap_oran = diameters / max_d;

coin_types = cell(num_coins, 1);
count_5TL = 0; count_1TL = 0; count_50kr = 0; count_25kr = 0;

for i = 1:num_coins
    if cap_oran(i) >= 0.96
        coin_types{i} = '5 TL';
        count_5TL = count_5TL + 1;
    elseif cap_oran(i) >= 0.88
        coin_types{i} = '1 TL';
        count_1TL = count_1TL + 1;
    elseif cap_oran(i) >= 0.75
        coin_types{i} = '50 Kr';
        count_50kr = count_50kr + 1;
    else
        coin_types{i} = '25 Kr';
        count_25kr = count_25kr + 1;
    end
end

toplam_TL = (count_5TL*500 + count_1TL*100 + count_50kr*50 + count_25kr*25) / 100;

%% 6. YAZI/TURA TESPITI
coin_sides = cell(num_coins, 1);
final_scores = zeros(num_coins, 1);

for i = 1:num_coins
    idx = valid_idx(i);
    bb = round(stats(idx).BoundingBox);
    
    x1 = max(1, bb(1));
    y1 = max(1, bb(2));
    x2 = min(bb(1)+bb(3), cols);
    y2 = min(bb(2)+bb(4), rows);
    
    coin_region = double(gray(y1:y2, x1:x2));
    [h, w] = size(coin_region);
    
    margin_y = round(h * 0.2);
    margin_x = round(w * 0.2);
    inner = coin_region(margin_y:h-margin_y, margin_x:w-margin_x);
    [ih, iw] = size(inner);
    
    % Simetri hesabi
    left_half = inner(:, 1:floor(iw/2));
    right_half = inner(:, ceil(iw/2)+1:end);
    min_w = min(size(left_half,2), size(right_half,2));
    left_half = left_half(:, end-min_w+1:end);
    right_half = fliplr(right_half(:, 1:min_w));
    simetri_skoru = 1 - (mean(abs(left_half(:) - right_half(:))) / 255);
    
    % Merkez std
    center_region = inner(round(ih*0.3):round(ih*0.7), round(iw*0.3):round(iw*0.7));
    merkez_std = std(center_region(:));
    
    % Kenar yogunlugu
    edges = edge(uint8(inner), 'canny');
    kenar_yogunluk = sum(edges(:)) / numel(edges);
    
    if strcmp(coin_types{i}, '5 TL')
        final_scores(i) = kenar_yogunluk * 100 + merkez_std * 0.5;
    else
        final_scores(i) = simetri_skoru * 50 + merkez_std * 0.3;
    end
end

% Her para turu icin siniflandirma
idx_5TL = find(strcmp(coin_types, '5 TL'));
idx_1TL = find(strcmp(coin_types, '1 TL'));
idx_50Kr = find(strcmp(coin_types, '50 Kr'));
idx_25Kr = find(strcmp(coin_types, '25 Kr'));

% 5 TL
if length(idx_5TL) >= 2
    esik_5TL = mean(final_scores(idx_5TL));
    for j = 1:length(idx_5TL)
        if final_scores(idx_5TL(j)) < esik_5TL
            coin_sides{idx_5TL(j)} = 'YAZI';
        else
            coin_sides{idx_5TL(j)} = 'TURA';
        end
    end
elseif length(idx_5TL) == 1
    coin_sides{idx_5TL(1)} = 'YAZI';
end

% 1 TL
if length(idx_1TL) >= 2
    esik_1TL = mean(final_scores(idx_1TL));
    for j = 1:length(idx_1TL)
        if final_scores(idx_1TL(j)) >= esik_1TL
            coin_sides{idx_1TL(j)} = 'YAZI';
        else
            coin_sides{idx_1TL(j)} = 'TURA';
        end
    end
elseif length(idx_1TL) == 1
    coin_sides{idx_1TL(1)} = 'YAZI';
end

% 50 Kr
if length(idx_50Kr) >= 2
    esik_50Kr = mean(final_scores(idx_50Kr));
    for j = 1:length(idx_50Kr)
        if final_scores(idx_50Kr(j)) >= esik_50Kr
            coin_sides{idx_50Kr(j)} = 'YAZI';
        else
            coin_sides{idx_50Kr(j)} = 'TURA';
        end
    end
elseif length(idx_50Kr) == 1
    coin_sides{idx_50Kr(1)} = 'YAZI';
end

% 25 Kr
if length(idx_25Kr) >= 2
    esik_25Kr = mean(final_scores(idx_25Kr));
    for j = 1:length(idx_25Kr)
        if final_scores(idx_25Kr(j)) >= esik_25Kr
            coin_sides{idx_25Kr(j)} = 'YAZI';
        else
            coin_sides{idx_25Kr(j)} = 'TURA';
        end
    end
elseif length(idx_25Kr) == 1
    coin_sides{idx_25Kr(1)} = 'YAZI';
end

count_yazi = sum(strcmp(coin_sides, 'YAZI'));
count_tura = sum(strcmp(coin_sides, 'TURA'));

%% 7. SONUCLARI GORSELLESTIR
figure('Name', 'Odev 4 - Para Tespiti', 'Position', [50, 50, 1200, 800]);
imshow(img);
hold on;

for i = 1:num_coins
    idx = valid_idx(i);
    cx = stats(idx).Centroid(1);
    cy = stats(idx).Centroid(2);
    r = diameters(i) / 2;
    
    if strcmp(coin_types{i}, '5 TL')
        renk = [1, 0.8, 0];
    elseif strcmp(coin_types{i}, '1 TL')
        renk = [1, 0, 0];
    elseif strcmp(coin_types{i}, '50 Kr')
        renk = [1, 0, 1];
    else
        renk = [0, 0, 1];
    end
    
    theta = linspace(0, 2*pi, 100);
    plot(cx + r*cos(theta), cy + r*sin(theta), 'Color', renk, 'LineWidth', 4);
    
    text(cx, cy-25, coin_types{i}, 'Color', 'white', 'FontSize', 16, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'BackgroundColor', renk);
    text(cx, cy+25, coin_sides{i}, 'Color', 'yellow', 'FontSize', 14, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'BackgroundColor', 'black');
end

baslik = sprintf(['PARA SAYMA ve YAZI/TURA TESPITI\n' ...
    '5 TL: %d (Sari) | 1 TL: %d (Kirmizi) | 50 Kr: %d (Pembe) | 25 Kr: %d (Mavi)\n' ...
    'TOPLAM: %d para = %.2f TL | YAZI: %d | TURA: %d'], ...
    count_5TL, count_1TL, count_50kr, count_25kr, num_coins, toplam_TL, count_yazi, count_tura);
title(baslik, 'FontSize', 14, 'FontWeight', 'bold');
hold off;

saveas(gcf, 'sonuc.png');

%% 8. KENAR ANALIZI
figure('Name', 'Kenar Analizi', 'Position', [100, 100, 1000, 600]);

for i = 1:num_coins
    idx = valid_idx(i);
    bb = round(stats(idx).BoundingBox);
    x1 = max(1, bb(1)); y1 = max(1, bb(2));
    x2 = min(bb(1)+bb(3), cols); y2 = min(bb(2)+bb(4), rows);
    
    coin_region = gray(y1:y2, x1:x2);
    edges = edge(coin_region, 'canny');
    
    subplot(3, 3, i);
    imshow(edges);
    title(sprintf('%s - %s', coin_types{i}, coin_sides{i}), 'FontSize', 10);
end
sgtitle('Kenar Desenleri', 'FontSize', 14);

saveas(gcf, 'kenar.png');

%% 9. SONUC YAZDIRMA
fprintf('\n============================================\n');
fprintf('         KISIM A: PARA SAYMA               \n');
fprintf('============================================\n');
fprintf(' 5 TL     : %d adet = %4d kurus\n', count_5TL, count_5TL*500);
fprintf(' 1 TL     : %d adet = %4d kurus\n', count_1TL, count_1TL*100);
fprintf(' 50 Kurus : %d adet = %4d kurus\n', count_50kr, count_50kr*50);
fprintf(' 25 Kurus : %d adet = %4d kurus\n', count_25kr, count_25kr*25);
fprintf('--------------------------------------------\n');
fprintf(' TOPLAM   : %d para = %.2f TL\n', num_coins, toplam_TL);
fprintf('============================================\n');
fprintf('       KISIM B: YAZI/TURA TESPITI          \n');
fprintf('============================================\n');
fprintf(' YAZI     : %d adet\n', count_yazi);
fprintf(' TURA     : %d adet\n', count_tura);
fprintf('============================================\n');