CREATE OR REPLACE FUNCTION make_triangle_grid(geom geometry, side_meters decimal)
RETURNS SETOF geometry AS $BODY$
DECLARE
	srid INTEGER := 3857;
	input_srid INTEGER;
	x_max DECIMAL;
	y_max DECIMAL;
	x_min DECIMAL;
	y_min DECIMAL;
	x_series DECIMAL;-- absolute value
	y_series DECIMAL;-- absolute value
	geom_tri GEOMETRY := ST_GeomFromText(FORMAT('POLYGON((0 0, %s %s, %s %s, 0 0))',
	                                        (side_meters), (0), (side_meters * .5), (side_meters) ), srid);
BEGIN
    CASE st_srid(geom) WHEN 0 THEN
        geom := ST_SetSRID(geom, 3857);
        RAISE NOTICE 'SRID Not Found.';
    ELSE
        RAISE NOTICE 'SRID Found.';
    END CASE;
    input_srid:=st_srid(geom);
    geom := st_transform(geom, srid);
    CASE use_envelope WHEN true THEN
        geom := st_envelope(geom);
        RAISE NOTICE'Using min/max for ST_Envelope on geom';
    ELSE 
        RAISE NOTICE'Using min/max for geom';
    END CASE;
    x_max := ST_XMax(geom);
    y_max := ST_YMax(geom);
    x_min := ST_XMin(geom);
    y_min := ST_YMin(geom);
    x_series := CEIL ( @( x_max - x_min ) / side_meters );
    y_series := CEIL ( @( y_max - y_min ) / side_meters);
    RETURN QUERY
            with foo as(
                SELECT
                    ST_Translate ( cell, x*side_meters+x_min, y*side_meters+y_min) AS grid
                FROM
                    generate_series ( 0, X_series, 1) AS x,
                    generate_series ( 0, y_series, 1) AS y,
                    ( 
                        SELECT geom_tri AS cell
                            union
                        SELECT st_rotate(geom_tri, pi(), side_meters*.75, side_meters * .5)  as cell
                    ) AS foo where st_within(ST_Translate(cell, x*side_meters+x_min, y*side_meters+y_min ), geom)
            ) select ST_transform(st_collect(grid), input_srid) from foo ;
END;
$BODY$ LANGUAGE 'plpgsql' VOLATILE;