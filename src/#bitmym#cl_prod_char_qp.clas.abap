CLASS /BITMYM/CL_PROD_CHAR_QP DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_prod_char,
        charcinternalid     TYPE /bitmym/i_class_charac-charcinternalid,
        charcpositionnumber TYPE /bitmym/i_class_charac-charcpositionnumber,
        timeintervalnumber  TYPE /bitmym/i_class_charac-timeintervalnumber,
        class               TYPE /bitmym/i_class_charac-class,
        classtype           TYPE /bitmym/i_class_charac-classtype,
        characteristic      TYPE /bitmym/i_class_charac-characteristic,
        charcdescription    TYPE /bitmym/c_charcbasiclist-charcdescription,
      END OF ty_prod_char,
      tty_prod_char TYPE STANDARD TABLE OF ty_prod_char WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_char_assigned_value,
        charcinternalid           TYPE /bitmym/i_assort_characteristc-charcinternalid,
        charcvaluepositionnumber  TYPE /bitmym/i_assort_characteristc-charcvaluepositionnumber,
        charvalue                 TYPE /bitmym/i_assort_characteristc-charvalue,
*        charcvalpositionnumber    TYPE /bitmym/i_assort_characteristc-charcvalpositionnumber,
        characteristics           TYPE /bitmym/i_assort_characteristc-characteristics,
        datatype                  TYPE /bitmym/i_assort_characteristc-datatype,
        checktable                TYPE /bitmym/i_assort_characteristc-checktable,
        characteristicdescription TYPE /bitmym/i_assort_characteristc-characteristicdescription,
      END OF ty_char_assigned_value,
      tty_char_assigned_value TYPE STANDARD TABLE OF ty_char_assigned_value WITH EMPTY KEY.

    METHODS apply_paging_assigned
      IMPORTING
        iv_offset TYPE i
        iv_top    TYPE i
      CHANGING
        ct_data   TYPE tty_char_assigned_value.

    METHODS get_orderby_clause_assigned
      IMPORTING
        it_sort TYPE if_rap_query_request=>tt_sort_elements
      RETURNING
        VALUE(rv_orderby) TYPE string.

    METHODS get_where_clause_assigned
      IMPORTING
        io_filter TYPE REF TO if_rap_query_filter
      RETURNING
        VALUE(rv_where) TYPE string.

    METHODS get_root_node
      IMPORTING io_filter TYPE REF TO if_rap_query_filter
      RETURNING VALUE(rv_root_node) TYPE /bitmym/i_product_catalog_hry-nodeid.

    METHODS get_max_depth_from_filter
      IMPORTING io_filter TYPE REF TO if_rap_query_filter
      RETURNING VALUE(rv_max_depth) TYPE i.

    METHODS apply_paging
      IMPORTING iv_offset TYPE i iv_top TYPE i
      CHANGING  ct_data   TYPE tty_prod_char.

    METHODS get_orderby_clause
      IMPORTING it_sort TYPE if_rap_query_request=>tt_sort_elements
      RETURNING VALUE(rv_orderby) TYPE string.

    METHODS get_where_clause
      IMPORTING io_filter TYPE REF TO if_rap_query_filter
      RETURNING VALUE(rv_where) TYPE string.

ENDCLASS.



CLASS /BITMYM/CL_PROD_CHAR_QP IMPLEMENTATION.

METHOD if_rap_query_provider~select.

  DATA:
    lv_count           TYPE int8,
    lv_data_requested  TYPE abap_bool,
    lv_count_requested TYPE abap_bool,
    lv_page_size       TYPE i,
    lv_offset          TYPE i,
    lv_fetch_rows      TYPE i,
    lv_where           TYPE string,
    lv_orderby         TYPE string,
    lv_root_node       TYPE /bitmym/i_product_catalog_hry-nodeid,
    lv_max_depth       TYPE i.

  DATA(lv_entity) = io_request->get_entity_id( ).

  lv_data_requested  = io_request->is_data_requested( ).
  lv_count_requested = io_request->is_total_numb_of_rec_requested( ).

  IF lv_data_requested = abap_false
     AND lv_count_requested = abap_false.
    RETURN.
  ENDIF.

  DATA(lo_filter) = io_request->get_filter( ).
  DATA(lo_paging) = io_request->get_paging( ).
  DATA(lt_sort)   = io_request->get_sort_elements( ).

  lv_root_node = get_root_node( lo_filter ).
  lv_max_depth = get_max_depth_from_filter( lo_filter ).

  CLEAR: lv_offset, lv_page_size, lv_fetch_rows.

  IF lo_paging IS BOUND.
    lv_offset    = lo_paging->get_offset( ).
    lv_page_size = lo_paging->get_page_size( ).

    IF lv_page_size <> if_rap_query_paging=>page_size_unlimited.
      lv_fetch_rows = lv_offset + lv_page_size.
    ENDIF.
  ELSE.
    lv_offset     = 0.
    lv_page_size  = if_rap_query_paging=>page_size_unlimited.
    lv_fetch_rows = 0.
  ENDIF.

  CASE lv_entity.

    WHEN '/BITMYM/C_CHARCBASICLIST'.

      DATA lt_data TYPE tty_prod_char.

      lv_where   = get_where_clause( lo_filter ).
      lv_orderby = get_orderby_clause( lt_sort ).

      IF lv_data_requested = abap_true.

        IF lv_fetch_rows > 0.

          IF lv_where IS INITIAL.
            SELECT DISTINCT
                   a~charcinternalid,
                   a~characteristic,
                   a~charcdescription
              FROM /bitmym/i_class_charac AS a
              INNER JOIN /bitmym/i_product_catalog_hry(
                  p_root_node = @lv_root_node,
                  p_max_depth = @lv_max_depth ) AS b
                ON ( b~nodeid = a~classinternalid OR b~ParentNodeID = a~classinternalid )
               AND b~nodeobjecttype = 'K'
              ORDER BY (lv_orderby)
              INTO CORRESPONDING FIELDS OF TABLE @lt_data
              UP TO @lv_fetch_rows ROWS.
          ELSE.
            SELECT DISTINCT
                   a~charcinternalid,
                   a~characteristic,
                   a~charcdescription
              FROM /bitmym/i_class_charac AS a
              INNER JOIN /bitmym/i_product_catalog_hry(
                  p_root_node = @lv_root_node,
                  p_max_depth = @lv_max_depth ) AS b
                ON b~nodeid = a~classinternalid
               AND b~nodeobjecttype = 'K'
              WHERE (lv_where)
              ORDER BY (lv_orderby)
              INTO CORRESPONDING FIELDS OF TABLE @lt_data
              UP TO @lv_fetch_rows ROWS.
          ENDIF.

        ELSE.

          IF lv_where IS INITIAL.
            SELECT DISTINCT
                   a~charcinternalid,
                   a~characteristic,
                   a~charcdescription
              FROM /bitmym/i_class_charac AS a
              INNER JOIN /bitmym/i_product_catalog_hry(
                  p_root_node = @lv_root_node,
                  p_max_depth = @lv_max_depth ) AS b
                ON b~nodeid = a~classinternalid
               AND b~nodeobjecttype = 'K'
              ORDER BY (lv_orderby)
              INTO CORRESPONDING FIELDS OF TABLE @lt_data.
          ELSE.
            SELECT DISTINCT
                   a~charcinternalid,
                   a~characteristic,
                   a~charcdescription
              FROM /bitmym/i_class_charac AS a
              INNER JOIN /bitmym/i_product_catalog_hry(
                  p_root_node = @lv_root_node,
                  p_max_depth = @lv_max_depth ) AS b
                ON b~nodeid = a~classinternalid
               AND b~nodeobjecttype = 'K'
              WHERE (lv_where)
              ORDER BY (lv_orderby)
              INTO CORRESPONDING FIELDS OF TABLE @lt_data.
          ENDIF.

        ENDIF.

        IF lo_paging IS BOUND.
          IF lv_page_size = if_rap_query_paging=>page_size_unlimited.
            IF lv_offset > 0.
              apply_paging(
                EXPORTING
                  iv_offset = lv_offset
                  iv_top    = 0
                CHANGING
                  ct_data   = lt_data ).
            ENDIF.
          ELSE.
            apply_paging(
              EXPORTING
                iv_offset = lv_offset
                iv_top    = lv_page_size
              CHANGING
                ct_data   = lt_data ).
          ENDIF.
        ENDIF.

        io_response->set_data( lt_data ).
      ENDIF.

    WHEN '/BITMYM/C_CHAR_ASSIGNED_VALUE'.

      DATA lt_assigned TYPE tty_char_assigned_value.

      lv_where   = get_where_clause_assigned( lo_filter ).
      lv_orderby = get_orderby_clause_assigned( lt_sort ).

      IF lv_data_requested = abap_true.

        IF lv_fetch_rows > 0.

          IF lv_where IS INITIAL.
            SELECT DISTINCT
                   a~charcinternalid,
                   a~charcvaluepositionnumber,
                   a~charvalue,
                   a~characteristics,
                   a~datatype,
                   a~checktable,
                   a~characteristicdescription
              FROM /bitmym/i_assort_characteristc AS a
              INNER JOIN /bitmym/i_product_catalog_hry(
                  p_root_node = @lv_root_node,
                  p_max_depth = @lv_max_depth ) AS b
                ON b~nodeid = a~classobjectid
               AND b~nodeobjecttype = 'O'
              ORDER BY a~CharcInternalID, a~charvalue
              INTO CORRESPONDING FIELDS OF TABLE @lt_assigned
              UP TO @lv_fetch_rows ROWS.

            DELETE ADJACENT DUPLICATES FROM lt_assigned COMPARING charcinternalid charvalue.

          ELSE.
            SELECT DISTINCT
                   a~charcinternalid,
                   a~charcvaluepositionnumber,
                   a~charvalue,
*                   a~charcvalpositionnumber,
                   a~characteristics,
                   a~datatype,
                   a~checktable,
                   a~characteristicdescription
              FROM /bitmym/i_assort_characteristc AS a
              INNER JOIN /bitmym/i_product_catalog_hry(
                  p_root_node = @lv_root_node,
                  p_max_depth = @lv_max_depth ) AS b
                ON b~nodeid = a~classobjectid
               AND b~nodeobjecttype = 'O'
              WHERE (lv_where)
              ORDER BY (lv_orderby)
              INTO CORRESPONDING FIELDS OF TABLE @lt_assigned
              UP TO @lv_fetch_rows ROWS.
          ENDIF.

        ELSE.

          IF lv_where IS INITIAL.
            SELECT DISTINCT
                   a~charcinternalid,
                   a~charcvaluepositionnumber,
                   a~charvalue,
*                   a~charcvalpositionnumber,
                   a~characteristics,
                   a~datatype,
                   a~checktable,
                   a~characteristicdescription
              FROM /bitmym/i_assort_characteristc AS a
              INNER JOIN /bitmym/i_product_catalog_hry(
                  p_root_node = @lv_root_node,
                  p_max_depth = @lv_max_depth ) AS b
                ON b~nodeid = a~classobjectid
               AND b~nodeobjecttype = 'O'
              ORDER BY (lv_orderby)
              INTO CORRESPONDING FIELDS OF TABLE @lt_assigned.
          ELSE.
            SELECT DISTINCT
                   a~charcinternalid,
                   a~charcvaluepositionnumber,
                   a~charvalue,
*                   a~charcvalpositionnumber,
                   a~characteristics,
                   a~datatype,
                   a~checktable,
                   a~characteristicdescription
              FROM /bitmym/i_assort_characteristc AS a
              INNER JOIN /bitmym/i_product_catalog_hry(
                  p_root_node = @lv_root_node,
                  p_max_depth = @lv_max_depth ) AS b
                ON b~nodeid = a~classobjectid
               AND b~nodeobjecttype = 'O'
              WHERE (lv_where)
              ORDER BY (lv_orderby)
              INTO CORRESPONDING FIELDS OF TABLE @lt_assigned.
          ENDIF.

        ENDIF.

        IF lo_paging IS BOUND.
          IF lv_page_size = if_rap_query_paging=>page_size_unlimited.
            IF lv_offset > 0.
              apply_paging_assigned(
                EXPORTING
                  iv_offset = lv_offset
                  iv_top    = 0
                CHANGING
                  ct_data   = lt_assigned ).
            ENDIF.
          ELSE.
            apply_paging_assigned(
              EXPORTING
                iv_offset = lv_offset
                iv_top    = lv_page_size
              CHANGING
                ct_data   = lt_assigned ).
          ENDIF.
        ENDIF.

        io_response->set_data( lt_assigned ).
      ENDIF.

  ENDCASE.

ENDMETHOD.


METHOD get_root_node.

  DATA: ld_class_type  TYPE klah-klart,
        ld_class_num   TYPE klah-class,
        ls_area        TYPE /sopromet/zzl01,
        lt_name_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

  CLEAR rv_root_node.

  " 1. First try to get root node from RAP/UI filter
  IF io_filter IS BOUND.
    TRY.
        lt_name_ranges = io_filter->get_as_ranges( ).
      CATCH cx_root.
        CLEAR lt_name_ranges.
    ENDTRY.

    READ TABLE lt_name_ranges INTO DATA(ls_name_range)
      WITH KEY name = 'PARENTNODEID'.
    IF sy-subrc = 0 AND ls_name_range-range IS NOT INITIAL.
      READ TABLE ls_name_range-range INTO DATA(ls_range) INDEX 1.
      IF sy-subrc = 0 AND ls_range-low IS NOT INITIAL.
        rv_root_node = CONV /bitmym/i_product_catalog_hry-parentnodeid( ls_range-low ).
        RETURN.
      ENDIF.
    ENDIF.
  ENDIF.

  " 2. Fallback to existing UI5 logic
  DATA(go_ui5) = NEW /bitmym/cl_ui5(
    id_rap_framework = abap_true ).

  CHECK go_ui5 IS BOUND.

  go_ui5->fill_comwa_from_header( ).
  go_ui5->start_sales_area( ).

  DATA(ls_data) = go_ui5->get_data( ).

  ls_data-go_sales_area->get_property(
    EXPORTING
      i_feld  = 'GS_ACTUAL_AREA'
    IMPORTING
      e_value = ls_area ).

  CHECK ls_area-klart_search IS NOT INITIAL
    AND ls_area-class_search IS NOT INITIAL.

  ld_class_type = ls_area-klart_search.
  ld_class_num  = ls_area-class_search.

  " 3. Convert class number -> internal class ID from I_ClassHeader
  SELECT SINGLE classinternalid
    FROM i_classheader
    WHERE class     = @ld_class_num
      AND classtype = @ld_class_type
    INTO @DATA(lv_nodeid).

  IF sy-subrc = 0 AND lv_nodeid IS NOT INITIAL.
    rv_root_node = lv_nodeid.
  ENDIF.

ENDMETHOD.

METHOD get_max_depth_from_filter.

  rv_max_depth = 99.

  TRY.
      DATA(lt_ranges) = io_filter->get_as_ranges( ).
      READ TABLE lt_ranges INTO DATA(ls_range)
        WITH KEY name = 'MAXDEPTH'.
      IF sy-subrc = 0 AND ls_range-range IS NOT INITIAL.
        rv_max_depth = CONV i( ls_range-range[ 1 ]-low ).
      ENDIF.
    CATCH cx_root.
  ENDTRY.

ENDMETHOD.


METHOD apply_paging.

  DATA lt_out TYPE tty_prod_char.

  IF iv_top = 0.
    LOOP AT ct_data INTO DATA(ls_row) FROM iv_offset + 1.
      APPEND ls_row TO lt_out.
    ENDLOOP.
  ELSE.
    LOOP AT ct_data INTO ls_row
         FROM iv_offset + 1
         TO   iv_offset + iv_top.
      APPEND ls_row TO lt_out.
    ENDLOOP.
  ENDIF.

  ct_data = lt_out.

ENDMETHOD.


METHOD get_orderby_clause.

  rv_orderby = 'A~CHARCINTERNALID ASCENDING'.

  LOOP AT it_sort INTO DATA(ls_sort).

    DATA(lv_field) = ``.

    CASE to_upper( ls_sort-element_name ).

      WHEN 'CHARCINTERNALID'.
        lv_field = 'A~CHARCINTERNALID'.
      WHEN 'CHARACTERISTIC'.
        lv_field = 'A~CHARACTERISTIC'.
      WHEN OTHERS.
        CONTINUE.
    ENDCASE.

    IF ls_sort-descending = abap_true.
      lv_field = |{ lv_field } DESCENDING|.
    ELSE.
      lv_field = |{ lv_field } ASCENDING|.
    ENDIF.

    rv_orderby = lv_field.

  ENDLOOP.

ENDMETHOD.

METHOD get_where_clause.

  DATA lt_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

  TRY.
      lt_ranges = io_filter->get_as_ranges( ).
    CATCH cx_root.
      RETURN.
  ENDTRY.

  LOOP AT lt_ranges INTO DATA(ls_name).

    " Dynamically build DB field name
    DATA(lv_sql_name) = |A~{ to_upper( ls_name-name ) }|.

    LOOP AT ls_name-range INTO DATA(ls_range).

      DATA(lv_val) = ls_range-low.
      REPLACE ALL OCCURRENCES OF '''' IN lv_val WITH ''''''.

      DATA lv_cond TYPE string.

      " Handle numeric vs character (simple heuristic)
      IF ls_range-option = 'EQ' AND ls_range-sign = 'I'.
        IF lv_val CO '0123456789'.
          lv_cond = |{ lv_sql_name } = { lv_val }|.
        ELSE.
          lv_cond = |{ lv_sql_name } = '{ lv_val }'|.
        ENDIF.
      ELSE.
        CONTINUE. " keep it simple for now
      ENDIF.

      IF rv_where IS INITIAL.
        rv_where = lv_cond.
      ELSE.
        rv_where = |{ rv_where } AND { lv_cond }|.
      ENDIF.

    ENDLOOP.

  ENDLOOP.

ENDMETHOD.

METHOD apply_paging_assigned.

  DATA lt_out TYPE tty_char_assigned_value.

  IF iv_top = 0.
    LOOP AT ct_data INTO DATA(ls_row) FROM iv_offset + 1.
      APPEND ls_row TO lt_out.
    ENDLOOP.
  ELSE.
    LOOP AT ct_data INTO ls_row
         FROM iv_offset + 1
         TO   iv_offset + iv_top.
      APPEND ls_row TO lt_out.
    ENDLOOP.
  ENDIF.

  ct_data = lt_out.

ENDMETHOD.


METHOD get_orderby_clause_assigned.

  rv_orderby = 'CHARCINTERNALID ASCENDING'.

  LOOP AT it_sort INTO DATA(ls_sort).

    DATA(lv_field) = ``.

    CASE to_upper( ls_sort-element_name ).
      WHEN 'CHARCINTERNALID'.
        lv_field = 'CHARCINTERNALID'.
      WHEN 'CHARVALUE'.
        lv_field = 'CHARVALUE'.
      WHEN 'CHARACTERISTICS'.
        lv_field = 'CHARACTERISTICS'.
      WHEN OTHERS.
        CONTINUE.
    ENDCASE.

    IF ls_sort-descending = abap_true.
      lv_field = |{ lv_field } DESCENDING|.
    ELSE.
      lv_field = |{ lv_field } ASCENDING|.
    ENDIF.

    rv_orderby = lv_field.
  ENDLOOP.

ENDMETHOD.


METHOD get_where_clause_assigned.

  DATA lt_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

  TRY.
      lt_ranges = io_filter->get_as_ranges( ).
    CATCH cx_root.
      RETURN.
  ENDTRY.

  LOOP AT lt_ranges INTO DATA(ls_name).

    DATA(lv_sql_name) = ``.

    CASE to_upper( ls_name-name ).
      WHEN 'CHARCINTERNALID'.
        lv_sql_name = 'A~CHARCINTERNALID'.
      WHEN 'CHARVALUE'.
        lv_sql_name = 'A~CHARVALUE'.
      WHEN 'CHARACTERISTICS'.
        lv_sql_name = 'A~CHARACTERISTICS'.
      WHEN 'DATATYPE'.
        lv_sql_name = 'A~DATATYPE'.
      WHEN OTHERS.
        CONTINUE.
    ENDCASE.

    LOOP AT ls_name-range INTO DATA(ls_range).

      DATA(lv_val) = ls_range-low.
      REPLACE ALL OCCURRENCES OF '''' IN lv_val WITH ''''''.

      DATA(lv_cond) = |{ lv_sql_name } = '{ lv_val }'|.

      IF rv_where IS INITIAL.
        rv_where = lv_cond.
      ELSE.
        rv_where = |{ rv_where } AND { lv_cond }|.
      ENDIF.

    ENDLOOP.
  ENDLOOP.

ENDMETHOD.
ENDCLASS.
