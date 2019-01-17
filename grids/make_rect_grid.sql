CREATE OR REPLACE FUNCTION make_rect_grid(
    geom geometry,
    height_meters double precision,
    width_meters double precision,
    use_envelope bool default false,
    OUT geometry
)
 RETURNS SETOF geometry
 LANGUAGE plpgsql
 IMMUTABLE STRICT
AS $function$ DECLARE
    x_max DECIMAL;
    y_max DECIMAL;
    x_min DECIMAL;
    y_min DECIMAL;
    srid INTEGER := 3857;
    input_srid INTEGER;
    x_series DECIMAL;
    y_series DECIMAL;
BEGIN
	CASE st_srid ( geom ) WHEN 0 THEN
		geom := ST_SetSRID ( geom, srid );
		RAISE NOTICE'SRID Not Found.';
	ELSE 
		RAISE NOTICE'SRID Found.';
	END CASE;
	input_srid := st_srid ( geom );
	geom := st_transform ( geom, srid );
    CASE use_envelope WHEN true THEN
	    geom := st_envelope(geom);
        RAISE NOTICE'Using min/max for ST_Envelope on geom';
    ELSE 
        RAISE NOTICE'Using min/max for geom';
    END CASE;
	x_max := ST_XMax ( geom );
	y_max := ST_YMax ( geom );
	x_min := ST_XMin ( geom );
	y_min := ST_YMin ( geom );
	x_series := ceil ( @( x_max - x_min ) / height_meters );
	y_series := ceil ( @( y_max - y_min ) / width_meters );
	RETURN QUERY
        WITH res AS (
            SELECT
                st_collect (st_setsrid ( ST_Translate ( cell, j * $2 + x_min, i * $3 + y_min ), srid )) AS grid 
            FROM
                generate_series ( 0, x_series ) AS j,
                generate_series ( 0, y_series ) AS i,
                ( 
                    SELECT ( 'POLYGON((0 0, 0 ' ||$3 || ', ' ||$2 || ' ' ||$3 || ', ' ||$2 || ' 0,0 0))' ) :: geometry AS cell 
                ) AS foo WHERE ST_Within ( st_setsrid ( ST_Translate ( cell, j * $2 + x_min, i * $3 + y_min ), srid ), geom )
		) SELECT st_transform ( grid, input_srid ) FROM res;
END;
$function$;