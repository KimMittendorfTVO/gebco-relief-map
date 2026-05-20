%% Create gebco_subset.json for Plotly / Google Sites
% This script extracts the buffered lease area from the GEBCO NetCDF file
% and writes a Plotly-ready JSON file.
%
% Required output convention for Plotly:
%   lon: 1 x nLon vector, increasing west-to-east
%   lat: 1 x nLat vector, increasing south-to-north
%   z  : nLat x nLon matrix, where z(i,j) = elevation at lat(i), lon(j)

clear
clc

% -------------------------------------------------------------------------
% User settings
% -------------------------------------------------------------------------
file = fullfile('..', 'gebco_2025_n18.0_s9.0_w-122.0_e-113.0.nc');
outfile = 'gebco_subset.json';

% Lease boundary
lat_box = [11.08333 11.08333 9.89500 9.89500 11.08333];
lon_box = [-117.816670 -116.066667 -116.066667 -117.816670 -117.816670];

% Buffer around lease area, degrees
buffer = 0.2;

% Downsampling for web performance.
% Use step = 1 for full GEBCO resolution, 2 to 5 for smaller JSON files.
step = 1;

% Optional fixed color range for matching the MATLAB figure.
% Leave as these values for consistent colorbar scaling across views.
color_min = -4600;
color_max = -3000;

% -------------------------------------------------------------------------
% Bounds
% -------------------------------------------------------------------------
latlim = [min(lat_box) max(lat_box)] + [-buffer buffer];
lonlim = [min(lon_box) max(lon_box)] + [-buffer buffer];

% -------------------------------------------------------------------------
% Read GEBCO data
% -------------------------------------------------------------------------
if ~isfile(file)
    error('GEBCO NetCDF file not found: %s', file)
end

lat = double(ncread(file, 'lat'));
lon = double(ncread(file, 'lon'));
z_raw = double(ncread(file, 'elevation'));

% Replace common GEBCO fill value
z_raw(z_raw == -32767) = NaN;

% -------------------------------------------------------------------------
% Subset indices
% -------------------------------------------------------------------------
ilat = lat >= latlim(1) & lat <= latlim(2);
ilon = lon >= lonlim(1) & lon <= lonlim(2);

if ~any(ilat)
    error('No latitude points found inside latlim [%g %g].', latlim(1), latlim(2))
end

if ~any(ilon)
    error('No longitude points found inside lonlim [%g %g].', lonlim(1), lonlim(2))
end

lat_sub = lat(ilat);
lon_sub = lon(ilon);

% GEBCO elevation is normally stored as elevation(lon, lat).
% Convert to Plotly shape: z rows are latitude, z columns are longitude.
if size(z_raw, 1) == numel(lon) && size(z_raw, 2) == numel(lat)
    z_sub = z_raw(ilon, ilat)';
elseif size(z_raw, 1) == numel(lat) && size(z_raw, 2) == numel(lon)
    z_sub = z_raw(ilat, ilon);
else
    error('Unexpected elevation dimensions. Size is %d x %d, lon length is %d, lat length is %d.', ...
        size(z_raw, 1), size(z_raw, 2), numel(lon), numel(lat))
end

% Sort latitude ascending and keep z aligned
[lat_sub, lat_order] = sort(lat_sub(:), 'ascend');
z_sub = z_sub(lat_order, :);

% Sort longitude ascending and keep z aligned
[lon_sub, lon_order] = sort(lon_sub(:), 'ascend');
z_sub = z_sub(:, lon_order);

% Downsample after sorting
lat_out = lat_sub(1:step:end);
lon_out = lon_sub(1:step:end);
z_out = z_sub(1:step:end, 1:step:end);

% -------------------------------------------------------------------------
% Build JSON structure
% -------------------------------------------------------------------------
gebco = struct();
gebco.lon = lon_out(:)';
gebco.lat = lat_out(:)';
gebco.z = z_out;

gebco.lease_lon = lon_box;
gebco.lease_lat = lat_box;
gebco.latlim = latlim;
gebco.lonlim = lonlim;
gebco.color_min = color_min;
gebco.color_max = color_max;

gebco.meta = struct();
gebco.meta.source_file = file;
gebco.meta.step = step;
gebco.meta.z_units = 'meters relative to mean sea level';
gebco.meta.z_shape = 'rows=lat, columns=lon';
gebco.meta.created_by = 'gen_json_fixed.m';

% jsonencode converts MATLAB NaN values to JSON null values in current MATLAB
% releases, which Plotly accepts as gaps.
jsonText = jsonencode(gebco);

fid = fopen(outfile, 'w');
if fid < 0
    error('Could not open output file for writing: %s', outfile)
end
fprintf(fid, '%s', jsonText);
fclose(fid);

% -------------------------------------------------------------------------
% Sanity checks printed to MATLAB command window
% -------------------------------------------------------------------------
fprintf('Created %s\n', outfile)
fprintf('Longitude range: %.6f to %.6f\n', min(lon_out), max(lon_out))
fprintf('Latitude range:  %.6f to %.6f\n', min(lat_out), max(lat_out))
fprintf('Number of longitude points: %d\n', numel(lon_out))
fprintf('Number of latitude points:  %d\n', numel(lat_out))
fprintf('Z size: %d x %d\n', size(z_out, 1), size(z_out, 2))
fprintf('Z range: %.1f to %.1f m\n', min(z_out(:), [], 'omitnan'), max(z_out(:), [], 'omitnan'))

if size(z_out, 1) ~= numel(lat_out) || size(z_out, 2) ~= numel(lon_out)
    error('Output dimension mismatch: z must be length(lat) x length(lon).')
end
