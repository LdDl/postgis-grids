CREATE OR REPLACE FUNCTION public.create_regular_grid
    ( geom geometry, x_side float8, y_side float8, OUT geometry )
    RETURNS SETOF geometry AS $BODY$ DECLARE
    x_max DECIMAL;
    y_max DECIMAL;
    x_min DECIMAL;
    y_min DECIMAL;
    srid INTEGER := 4326;
    input_srid INTEGER;
    x_series DECIMAL;
    y_series DECIMAL;
    geom_cell geometry := ST_GeomFromText(FORMAT('POLYGON((0 0, 0 %s, %s %s, %s 0,0 0))', $3, $2, $3, $2), srid);
    BEGIN
    CASE ST_SRID (geom) WHEN 0 THEN
        geom := ST_SetSRID (geom, srid);
        RAISE NOTICE'SRID Not Found.';
    ELSE
        RAISE NOTICE'SRID Found.';
    END CASE;
    input_srid := ST_srid ( geom );
    geom := ST_Transform ( geom, srid );
    x_max := ST_XMax ( geom );
    y_max := ST_YMax ( geom );
    x_min := ST_XMin ( geom );
    y_min := ST_YMin ( geom );
    x_series := CEIL ( @( x_max - x_min ) / x_side );
    y_series := CEIL ( @( y_max - y_min ) / y_side );

    RETURN QUERY With foo AS (
        SELECT
        ST_Translate( geom_cell, j * $2 + x_min, i * $3 + y_min ) AS cell
        FROM
            generate_series ( 0, x_series ) AS j,
            generate_series ( 0, y_series ) AS i
        ) SELECT ST_CollectionExtract(ST_Collect(ST_Transform ( ST_Intersection(cell, geom), input_srid)), 3)
        FROM foo where ST_intersects (cell, geom);
    END;
    $BODY$ LANGUAGE plpgsql IMMUTABLE STRICT;
