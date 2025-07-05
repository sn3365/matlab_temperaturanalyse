clear all

%% --- Einstellungen ---
% Pfad zur Temperaturdaten-TXT-Datei (aus SmartView exportiert)
txtFile = 'C:\xxxx\xxxx\xxxx.txt';

% Pfad zum zugehörigen Wärmebild im .jpg - Format (aus SmartView exportiert, mit Farbpalette "hoher Kontrast")
imageFile = 'C:\xxxx\xxxx\xxxx.jpg';

% Name der Ausgangs - Exceldatei wählen
xlFileName = 'xxxx_analysewerte.xlsx';

%% --- Bild laden und verarbeiten ---
img = imread(imageFile);
grayImg = rgb2gray(img);   % Umwandlung in Graustufen

% Nur mittlerer Bereich des Bildes für Rahmenerkennung analysieren
[height, width] = size(grayImg);
centerX = round(width / 2);
centerY = round(height / 2);
searchSize = round(height * 0.35);  % sollte in zukünftigen Versuchen der Abstand zwischen Wärmebildkamera und Messobjekt verkürzt werden,
                                                % muss die SearchSize evtl. vergrößert werden auf z.B. 40%
% Begrenzung des Suchbereichs
x1 = max(centerX - searchSize, 1);
x2 = min(centerX + searchSize, width);
y1 = max(centerY - searchSize, 1);
y2 = min(centerY + searchSize, height);

% Nur zentralen Ausschnitt analysieren
centerImg = grayImg(y1:y2, x1:x2);

% Schwellenwert für binarisiertes Bild
bw = centerImg > 250;  % Pixel mit sehr hoher Helligkeit = weißer Rahmen

% Kanten erkennen
edges = edge(bw, 'Canny');

% Rechtecke erkennen (potenzielle Rahmen)
stats = regionprops(edges, 'BoundingBox', 'Area', 'Centroid');

% Suche nach quadratischem Rechteck mit Seitenlänge zwischen 210 und 270 px,
% das die Bildmitte im Suchbereich enthält
maxArea = 0;
bestBox = [];
for i = 1:length(stats)
    box = stats(i).BoundingBox;
    centroid = stats(i).Centroid;
    w = box(3);
    h = box(4);
    ar = w / h;  % Seitenverhältnis
    if abs(ar - 1) < 0.12 && w >= 210 && w <= 270 && h >= 210 && h <= 270 % das erkannte Rechteck muss eine Seitenlänge zwischen 
                                                                          % diesen Werten aufweisen;
                                                                          % sollte sich der Abstand des Versuchsaufbaus ändern, 
                                                                          % müssen diese Werte evtl. angepasst werden, auch Seitenverhältnis hier anpassen!
        % Prüfen, ob der Mittelpunkt des Bildes im Rechteck liegt
        globalCenterX = centerX;
        globalCenterY = centerY;
        rectX = box(1) + x1 - 1;
        rectY = box(2) + y1 - 1;
        if globalCenterX >= rectX && globalCenterX <= rectX + w && ...
           globalCenterY >= rectY && globalCenterY <= rectY + h
            if stats(i).Area > maxArea
                maxArea = stats(i).Area;
                bestBox = box;
            end
        end
    end
end

if isempty(bestBox)
    error('Kein geeigneter quadratischer Rahmen gefunden.');
end

% Koordinaten im Originalbild zurückrechnen  
xStart = round(bestBox(1)) + x1 + 2;            % In diesen 4 Zeilen kann mit den jeweils
yStart = round(bestBox(2)) + y1 + 2;            % letzten Zahlen die Position 
boxWidth = round(bestBox(3) - 7);               % des erkannten Rahmens exakt
boxHeight = round(bestBox(4) - 7);              % angepasst werden, also ob dieser am inneren Rand des Rahmens liegen soll oder am äußeren

% Visualisierung: Rechteck im Bild markieren
figure;
imshow(img);
hold on;
rectangle('Position', [xStart, yStart, boxWidth, boxHeight], 'EdgeColor', 'g', 'LineWidth', 2., 'LineStyle','--');
title('Erkannter Rahmen im Originalbild');

% % Seitenverhältnis und Koordinaten ausgeben
aspectRatio = boxWidth / boxHeight;
fprintf('Erkannter Rahmen:\n');
fprintf('  Position: (x = %d, y = %d)\n', xStart, yStart);
fprintf('  Breite: %d px, Höhe: %d px\n', boxWidth, boxHeight);
fprintf('  Seitenverhältnis (B/H): %.3f\n', aspectRatio);

%% --- .txt-Datei aufbereiten ---

% Datei einlesen
inputFile = txtFile;     % Ursprungsdatei mit Header und Zeilennummern
outputFile = 'bereinigt.txt';   % Neue Datei, nur Zahlenmatrix
% Rohdaten als Zell-Array zeilenweise einlesen
raw = readlines(inputFile);

% Leeres Array für bereinigte Daten
cleanedData = strings(0);
% Durch alle Zeilen ab der 6. Zeile ersetzen (erste Datenzeile nach dem Header)
for i = 6:numel(raw)
    line = raw(i);

    % Kommas durch Punkte ersetzen (für numerische Werte)
    line = replace(line, ',', '.');

    % Zeile in Zellen aufspalten (tab-getrennt)
    elements = strsplit(line, '\t');

    % Erste Spalte (Zeilennummer) entfernen
    if numel(elements) > 1
        elements = elements(2:end);
    end
    % Elemente durch Leerzeichen verbinden
    cleanedLine = strjoin(elements, ' ');

    % In Ergebnisliste einfügen
    cleanedData(end+1) = cleanedLine;
end

% Ergebnis in eine neue Datei schreiben
writelines(cleanedData, outputFile);
fprintf('Bereinigte Datei gespeichert als: %s\n', outputFile);


%% --- Temperaturdaten laden ---
tempFull = readmatrix("bereinigt.txt");  % Matrix mit Temperaturwerten

% Sicherstellen, dass die Koordinaten innerhalb der Matrix liegen
[ymax, xmax] = size(tempFull);
xEnd = min(xStart + boxWidth - 1, xmax);
yEnd = min(yStart + boxHeight - 1, ymax);

% Temperaturdaten im erkannten Bereich ausschneiden
tempCropped = tempFull(yStart:yEnd, xStart:xEnd);

%% --- Visualisierung und Analyse ---
figure;
imagesc(tempCropped);
colorbar;
cb = colorbar;
cb.Label.Interpreter = 'latex';
cb.Label.String = '$\mathit{T}$ / $^\circ$C';
cb.Label.FontSize = 12;
axis off;
title('Visualisierung der zugeschnittenen Temperaturmatrix (°C)');
colormap('jet');

meanTemp = mean(tempCropped(:));
stdTemp = std(tempCropped(:));
vke = stdTemp/meanTemp;
K_T = 1 - vke;
Tmin = min(tempCropped(:));
Tmax = max(tempCropped(:));
Spannweite = Tmax - Tmin;
minmaxratio = Tmin/Tmax;

fprintf('minimale Temperatur (Tmin): %.4f\n', Tmin);
fprintf('maximale Temperatur (Tmax): %.4f\n', Tmax);
fprintf('Spannweite : %.4f\n', Spannweite);
fprintf('Verhaeltnis Tmin/Tmax (r): %.4f\n', minmaxratio);
fprintf('Durchschnittstemperatur Tm: %.4f\n', meanTemp);
fprintf('Standardabweichung σ: %.4f\n', stdTemp);
fprintf('Temperaturgleichverteilungskoeffizient κ_T: %.4f\n', K_T);

%% --- Analysewerte als .xlsx-Datei speichern ---
% Alle Werte in eine Zelle schreiben
resultHeaders = ["Tmin/C°", "Tmax/C°", "Spannweite/C°", "Tmin/Tmax", "Mittelwert/C°", "Standardabweichung", "κ_T"];
resultValues  = [Tmin, Tmax, Spannweite, minmaxratio, meanTemp, stdTemp, K_T];

% Alles in eine Tabelle umwandeln
resultsTable = array2table(resultValues, 'VariableNames', resultHeaders);

% Speichern unter gewünschtem Pfad
writetable(resultsTable, xlFileName);
fprintf('Analysewerte wurden gespeichert in: %s\n', xlFileName);
