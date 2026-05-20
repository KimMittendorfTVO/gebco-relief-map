%% Create high-resolution gebco_subset.json for Plotly / Google Sites
% This version keeps the native GEBCO points and optionally interpolates
% between them for a smoother web display.
%
% Plotly convention:
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

% Native data thinning. Keep this at 1 for maximum real GEBCO resolution.
native_step = 1;

% Display interpolation factor.
% 1 = no interpolation, 2 = smoother, 3 or 4 = very smooth but much larger JSON.
% Recommended starting value: 2.
interp_factor = 2;
interp_method = 'linear';

% Optional fixed color range for matching the MATLAB figure.
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

% Keep native GEBCO resolution unless native_step is intentionally increased
lat_native = lat_sub(1:native_step:end);
lon_native = lon_sub(1:native_step:end);
z_native = z_sub(1:native_step:end, 1:native_step:end);

% Optional interpolation for smoother display in Plotly.
% This does not add new measured bathymetry; it only smooths between grid nodes.
if interp_factor > 1
    n_lat_out = (numel(lat_native) - 1) * interp_factor + 1;
    n_lon_out = (numel(lon_native) - 1) * interp_factor + 1;

    lat_out = linspace(min(lat_native), max(lat_native), n_lat_out);
    lon_out = linspace(min(lon_native), max(lon_native), n_lon_out);

    [LonNative, LatNative] = meshgrid(lon_native, lat_native);
    [LonOut, LatOut] = meshgrid(lon_out, lat_out);

    z_out = interp2(LonNative, LatNative, z_native, LonOut, LatOut, interp_method);
else
    lat_out = lat_native(:)';
    lon_out = lon_native(:)';
    z_out = z_native;
end

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
gebco.meta.native_step = native_step;
gebco.meta.interp_factor = interp_factor;
gebco.meta.interp_method = interp_method;
gebco.meta.z_units = 'meters relative to mean sea level';
gebco.meta.z_shape = 'rows=lat, columns=lon';
gebco.meta.created_by = 'gen_json_highres.m';
gebco.meta.note = 'Interpolated grid is for smoother display only; it does not add new measured GEBCO detail.';

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
fprintf('Native longitude points: %d\n', numel(lon_native))
fprintf('Native latitude points:  %d\n', numel(lat_native))
fprintf('Output longitude points: %d\n', numel(lon_out))
fprintf('Output latitude points:  %d\n', numel(lat_out))
fprintf('Z size: %d x %d\n', size(z_out, 1), size(z_out, 2))
fprintf('Z range: %.1f to %.1f m\n', min(z_out(:), [], 'omitnan'), max(z_out(:), [], 'omitnan'))
fprintf('Interpolation factor: %d\n', interp_factor)
fprintf('Estimated JSON grid values: %d\n', numel(z_out))

if size(z_out, 1) ~= numel(lat_out) || size(z_out, 2) ~= numel(lon_out)
    error('Output dimension mismatch: z must be length(lat) x length(lon).')
end
