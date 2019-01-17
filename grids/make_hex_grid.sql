CREATE OR REPLACE FUNCTION make_hex_grid(
    geom geometry,
    diameter_meters double precision,
    use_envelope bool default false
)
 RETURNS SETOF geometry
 LANGUAGE plpgsql
AS $function$
DECLARE
	srid INTEGER := 3857;
	input_srid INTEGER;
	x_max DECIMAL;
	y_max DECIMAL;
	x_min DECIMAL;
	y_min DECIMAL;
	x_series DECIMAL;
	y_series DECIMAL;
	b float :=diameter_meters/2;
    a float :=b/2; --sin(30)=.5
    c float :=2*a;
 	--temp     GEOMETRY := ST_GeomFromText(FORMAT('POLYGON((0 0, %s %s, %s %s, %s %s, %s %s, %s %s, 0 0))',
    --                       (b), (a), (b), (a+c), (0), (a+c+a), (-1*b), (a+c), (-1*b), (a)), srid);
	geom_grid     GEOMETRY := ST_GeomFromText(FORMAT('POLYGON((0 0, %s %s, %s %s, %s %s, %s %s, %s %s, 0 0))',
                          (diameter_meters *  0.5), (diameter_meters * 0.25),
                          (diameter_meters *  0.5), (diameter_meters * 0.75),
                                       0 ,  diameter_meters,
                          (diameter_meters * -0.5), (diameter_meters * 0.75),
                          (diameter_meters * -0.5), (diameter_meters * 0.25)), srid);

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
		x_series := ceil ( @( x_max - x_min ) / diameter_meters );
		y_series := ceil ( @( y_max - y_min ) / diameter_meters);
    RETURN QUERY
            with foo as(
                SELECT
                    st_setsrid (ST_Translate ( cell, x*(2*a+c)+x_min, y*(2*(c+a))+y_min), srid) AS hexa
                FROM
                    generate_series ( 0, x_series, 1) AS x,
                    generate_series ( 0, y_series, 1) AS y,
                    (
                        SELECT geom_grid AS cell
                            union
                        SELECT ST_Translate(geom_grid::geometry, b , a+c)  as cell
                    ) AS foo where st_within(st_setsrid (ST_Translate ( cell, x*(2*a+c)+x_min, y*(2*(c+a))+y_min), srid), geom)
            ) select ST_transform(st_collect(hexa), input_srid) from foo;
END;
$function$;