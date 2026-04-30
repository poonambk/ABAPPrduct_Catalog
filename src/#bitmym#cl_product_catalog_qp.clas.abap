CLASS /BITMYM/CL_PRODUCT_CATALOG_QP DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_product_catalog,
        nodeid           TYPE /bitmym/i_product_catalog_hry-nodeid,
        parentnodeid     TYPE /bitmym/i_product_catalog_hry-parentnodeid,
        nodetext         TYPE /bitmym/i_product_catalog_hry-nodetext,
        nodeclass        TYPE /bitmym/i_product_catalog_hry-nodeclass,
        nodeobjecttype   TYPE /bitmym/i_product_catalog_hry-nodeobjecttype,
        maxdepth         TYPE /bitmym/i_product_catalog_adv-maxdepth,
        parenttext       TYPE /bitmym/i_product_catalog_hry-parenttext,
        hierarchylevel   TYPE /bitmym/i_product_cat_hry_adv-hierarchylevel,
        hierarchyparentrank TYPE /bitmym/i_product_cat_hry_adv-hierarchyparentrank,
        hierarchytreesize TYPE /bitmym/i_product_cat_hry_adv-hierarchytreesize,
        drillstate       TYPE /bitmym/c_product_catalog_adv-drillstate,
        statusflag       TYPE /bitmym/i_product_catalog_adv-statusflag,
        _characteristics TYPE STANDARD TABLE OF /bitmym/i_classification WITH EMPTY KEY,
        _child           TYPE STANDARD TABLE OF /bitmym/i_product_catalog_hry WITH EMPTY KEY,
      END OF ty_product_catalog,
      tty_product_catalog TYPE STANDARD TABLE OF ty_product_catalog WITH EMPTY KEY.

    DATA gv_source_cds TYPE string.

    METHODS get_root_node
      IMPORTING
        io_filter           TYPE REF TO if_rap_query_filter
      RETURNING
        VALUE(rv_root_node) TYPE /bitmym/i_product_catalog_hry-nodeid.

    METHODS get_max_depth_from_filter
      IMPORTING
        io_filter           TYPE REF TO if_rap_query_filter
      RETURNING
        VALUE(rv_max_depth) TYPE i.

    METHODS apply_paging
      IMPORTING
        iv_offset TYPE i
        iv_top    TYPE i
      CHANGING
        ct_data   TYPE tty_product_catalog.

    METHODS get_orderby_clause
      IMPORTING
        it_sort             TYPE if_rap_query_request=>tt_sort_elements
      RETURNING
        VALUE(rv_orderby)   TYPE string.

    METHODS apply_sorting
      IMPORTING
        it_sort TYPE if_rap_query_request=>tt_sort_elements
      CHANGING
        ct_data TYPE tty_product_catalog.

    METHODS get_where_clause
      IMPORTING
        io_filter                TYPE REF TO if_rap_query_filter
        iv_search_expression     TYPE string
      RETURNING
        VALUE(rv_where)          TYPE string.

    METHODS get_select_list_from_request
      IMPORTING
        io_request               TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rv_select_list)    TYPE string.

    METHODS apply_characteristic_filters
      IMPORTING
        io_filter TYPE REF TO if_rap_query_filter
      CHANGING
        ct_data   TYPE tty_product_catalog.

ENDCLASS.



CLASS /BITMYM/CL_PRODUCT_CATALOG_QP IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA:
      lt_data            TYPE tty_product_catalog,
      lv_root_node       TYPE /bitmym/i_product_catalog_hry-nodeid,
      lv_max_depth       TYPE i,
      lv_count           TYPE int8,
      lv_data_requested  TYPE abap_bool,
      lv_count_requested TYPE abap_bool,
      lv_page_size       TYPE i,
      lv_offset          TYPE i,
      lv_fetch_rows      TYPE i,
      lv_where           TYPE string,
      lv_orderby         TYPE string.

    lv_data_requested = io_request->is_data_requested( ).
    DATA(lv_entity) = io_request->get_entity_id( ).

    IF lv_entity = '/BITMYM/C_PRODUCT_CATALOG'.
      gv_source_cds = '/BITMYM/I_PRODUCT_CATALOG_HRY'.
    ELSEIF lv_entity = '/BITMYM/C_CHARCBASICLIST'.
      gv_source_cds = '/BITMYM/I_CLASS_CHARAC'.
    ELSE.
      gv_source_cds = '/BITMYM/I_PRODUCT_CATALOG_HRY'.
    ENDIF.

    lv_count_requested = io_request->is_total_numb_of_rec_requested( ).

    IF lv_data_requested = abap_false
       AND lv_count_requested = abap_false.
      RETURN.
    ENDIF.

    DATA(lo_filter) = io_request->get_filter( ).

    lv_root_node = get_root_node( lo_filter ).
    lv_max_depth = get_max_depth_from_filter( lo_filter ).

    DATA(lo_paging) = io_request->get_paging( ).
    CLEAR: lv_offset, lv_page_size, lv_fetch_rows.

    IF lo_paging IS BOUND.
      lv_offset = lo_paging->get_offset( ).
      lv_page_size = lo_paging->get_page_size( ).
    ENDIF.

    DATA(lt_sort) = io_request->get_sort_elements( ).
    DATA(lv_search_expression) = io_request->get_search_expression( ).
    lv_where = get_where_clause(
      io_filter            = lo_filter
      iv_search_expression = lv_search_expression ).
    lv_orderby = get_orderby_clause( lt_sort ).

    DATA lv_has_char_filter TYPE abap_bool VALUE abap_false.
    IF lo_filter IS BOUND.
      TRY.
          DATA(lt_name_ranges) = lo_filter->get_as_ranges( ).
        CATCH cx_root.
          CLEAR lt_name_ranges.
      ENDTRY.

      LOOP AT lt_name_ranges INTO DATA(ls_name_range).
        IF to_upper( ls_name_range-name ) CP '_CHARACTERISTICS*'.
          lv_has_char_filter = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    DATA lv_expand_char TYPE abap_bool VALUE abap_false.
    DATA lv_expand_child TYPE abap_bool VALUE abap_false.

    DATA(lt_expand) = io_request->get_requested_elements( ).
    LOOP AT lt_expand INTO DATA(ls_expand).
      CASE ls_expand.
        WHEN '_CHARACTERISTICS'.
          lv_expand_char = abap_true.
        WHEN '_CHILD'.
          lv_expand_child = abap_true.
      ENDCASE.
    ENDLOOP.

    IF lo_paging IS BOUND
       AND lv_page_size <> if_rap_query_paging=>page_size_unlimited.
      lv_fetch_rows = lv_offset + lv_page_size.
    ENDIF.
    " Characteristic filters are resolved on association data in ABAP,
    " so we need the full root set before paging.
    IF lv_has_char_filter = abap_true.
      CLEAR lv_fetch_rows.
    ENDIF.

    DATA(lv_select_list) = get_select_list_from_request( io_request ).
    DATA lv_from_syntax TYPE string.

    lv_from_syntax = |{ gv_source_cds }( p_root_node = @lv_root_node, p_max_depth = @lv_max_depth )|.

    IF lv_where IS INITIAL.
      IF lv_fetch_rows > 0.
        SELECT (lv_select_list)
          FROM (lv_from_syntax)
          ORDER BY (lv_orderby)
          INTO CORRESPONDING FIELDS OF TABLE @lt_data
          UP TO @lv_fetch_rows ROWS.
      ELSE.
        SELECT (lv_select_list)
          FROM (lv_from_syntax)
          ORDER BY (lv_orderby)
          INTO CORRESPONDING FIELDS OF TABLE @lt_data.
      ENDIF.
    ELSE.
      IF lv_fetch_rows > 0.
        SELECT DISTINCT (lv_select_list)
          FROM (lv_from_syntax)
          WHERE (lv_where)
          ORDER BY (lv_orderby)
          INTO CORRESPONDING FIELDS OF TABLE @lt_data
          UP TO @lv_fetch_rows ROWS.
      ELSE.
        SELECT DISTINCT (lv_select_list)
          FROM (lv_from_syntax)
          WHERE (lv_where)
          ORDER BY (lv_orderby)
          INTO CORRESPONDING FIELDS OF TABLE @lt_data.
      ENDIF.
    ENDIF.

    IF lv_expand_char = abap_true AND lt_data IS NOT INITIAL.
      SELECT a~nodeid,
             b~*
        FROM @lt_data AS a
        INNER JOIN /BITMYM/I_Classification AS b
          ON b~ClfnObjectID = a~nodeid
        INTO TABLE @DATA(lt_joined_char).

      LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
        <ls_data>-_characteristics =
          VALUE #(
            FOR ls_join IN lt_joined_char
            WHERE ( nodeid = <ls_data>-nodeid )
            ( CORRESPONDING #( ls_join ) )
          ).
      ENDLOOP.
    ENDIF.

    IF lv_has_char_filter = abap_true.
      apply_characteristic_filters(
        EXPORTING
          io_filter = lo_filter
        CHANGING
          ct_data   = lt_data ).
    ENDIF.

    IF lv_expand_child = abap_true AND lt_data IS NOT INITIAL.
      SELECT
        _child~NodeID,
        _child~ParentNodeID,
        _child~ClassType,
        _child~NodeText,
        _child~NodeClass,
        _child~ParentText,
        _child~NodeObjectType
        FROM @lt_data AS _parent
        INNER JOIN /BITMYM/I_PRODUCT_CLASS AS _child
          ON _child~parentnodeid = _parent~nodeid
        INTO TABLE @DATA(lt_child_joined).

      LOOP AT lt_data ASSIGNING <ls_data>.
        <ls_data>-_child =
          VALUE #(
            FOR ls_child IN lt_child_joined
            WHERE ( parentnodeid = <ls_data>-nodeid )
            ( nodeid         = ls_child-nodeid
              parentnodeid   = ls_child-parentnodeid
              nodetext       = ls_child-nodetext
              nodeclass      = ls_child-nodeclass
              nodeobjecttype = ls_child-nodeobjecttype
              parenttext     = ls_child-parenttext )
          ).
      ENDLOOP.
    ENDIF.

    IF lv_count_requested = abap_true.
      IF lv_has_char_filter = abap_true.
        lv_count = lines( lt_data ).
      ELSE.
        IF lv_where IS INITIAL.
          SELECT COUNT( * )
            FROM (lv_from_syntax)
            INTO @lv_count.
        ELSE.
          SELECT COUNT( * )
            FROM (lv_from_syntax)
            WHERE (lv_where)
            INTO @lv_count.
        ENDIF.
      ENDIF.

      io_response->set_total_number_of_records( lv_count ).
    ENDIF.

    IF lv_data_requested = abap_true.
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

  ENDMETHOD.


  METHOD get_root_node.
    DATA: ld_class_type  TYPE klah-klart,
          ld_class_num   TYPE klah-class,
          ls_area        TYPE /sopromet/zzl01,
          lt_name_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    CLEAR rv_root_node.

    IF gv_source_cds = '/BITMYM/I_PRODUCT_CATALOG_HRY'.
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
          IF sy-subrc = 0.
            rv_root_node = CONV /bitmym/i_product_catalog_hry-parentnodeid( ls_range-low ).
            RETURN.
          ENDIF.
        ENDIF.
      ENDIF.
    ELSE.
      IF io_filter IS BOUND.
        TRY.
            lt_name_ranges = io_filter->get_as_ranges( ).
          CATCH cx_root.
            CLEAR lt_name_ranges.
        ENDTRY.

        READ TABLE lt_name_ranges INTO ls_name_range
          WITH KEY name = 'PARENTNODEID'.
        IF sy-subrc = 0 AND ls_name_range-range IS NOT INITIAL.
          READ TABLE ls_name_range-range INTO ls_range INDEX 1.
          IF sy-subrc = 0 AND ls_range-low IS NOT INITIAL.
            rv_root_node = CONV /bitmym/i_product_catalog_hry-parentnodeid( ls_range-low ).
            RETURN.
          ENDIF.
        ENDIF.
      ENDIF.

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
      ld_class_num = ls_area-class_search.

      SELECT SINGLE ClassInternalID
        FROM I_ClassHeader
        WHERE Class     = @ld_class_num
          AND ClassType = @ld_class_type
        INTO @DATA(lv_nodeid).

      IF sy-subrc = 0 AND lv_nodeid IS NOT INITIAL.
        rv_root_node = lv_nodeid.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD get_max_depth_from_filter.
    DATA lt_name_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    rv_max_depth = 99.

    IF io_filter IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        lt_name_ranges = io_filter->get_as_ranges( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    READ TABLE lt_name_ranges INTO DATA(ls_name_range)
      WITH KEY name = 'MAXDEPTH'.
    IF sy-subrc <> 0.
      READ TABLE lt_name_ranges INTO ls_name_range
        WITH KEY name = 'MaxDepth'.
    ENDIF.
    IF sy-subrc <> 0.
      READ TABLE lt_name_ranges INTO ls_name_range
        WITH KEY name = 'P_MAX_DEPTH'.
    ENDIF.
    IF sy-subrc <> 0.
      READ TABLE lt_name_ranges INTO ls_name_range
        WITH KEY name = 'maxdepth'.
    ENDIF.

    IF sy-subrc = 0 AND ls_name_range-range IS NOT INITIAL.
      READ TABLE ls_name_range-range INTO DATA(ls_range) INDEX 1.
      IF sy-subrc = 0 AND ls_range-low IS NOT INITIAL.
        TRY.
            rv_max_depth = CONV i( ls_range-low ).
          CATCH cx_sy_conversion_no_number cx_sy_conversion_overflow.
            rv_max_depth = 99.
        ENDTRY.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD apply_paging.
    DATA:
      lt_paged TYPE tty_product_catalog,
      lv_from  TYPE i,
      lv_to    TYPE i,
      lv_lines TYPE i.

    lv_lines = lines( ct_data ).

    IF lv_lines = 0.
      CLEAR ct_data.
      RETURN.
    ENDIF.

    lv_from = iv_offset + 1.

    IF lv_from > lv_lines.
      CLEAR ct_data.
      RETURN.
    ENDIF.

    IF iv_top IS INITIAL.
      lv_to = lv_lines.
    ELSE.
      lv_to = iv_offset + iv_top.
      IF lv_to > lv_lines.
        lv_to = lv_lines.
      ENDIF.
    ENDIF.

    LOOP AT ct_data INTO DATA(ls_row) FROM lv_from TO lv_to.
      APPEND ls_row TO lt_paged.
    ENDLOOP.

    ct_data = lt_paged.
  ENDMETHOD.


  METHOD apply_sorting.
    LOOP AT it_sort INTO DATA(ls_sort).
      CASE ls_sort-element_name.
        WHEN 'NODEID'.
          IF ls_sort-descending = abap_true.
            SORT ct_data BY nodeid DESCENDING.
          ELSE.
            SORT ct_data BY nodeid ASCENDING.
          ENDIF.

        WHEN 'PARENTNODEID'.
          IF ls_sort-descending = abap_true.
            SORT ct_data BY parentnodeid DESCENDING.
          ELSE.
            SORT ct_data BY parentnodeid ASCENDING.
          ENDIF.

        WHEN 'NODETEXT'.
          IF ls_sort-descending = abap_true.
            SORT ct_data BY nodetext DESCENDING.
          ELSE.
            SORT ct_data BY nodetext ASCENDING.
          ENDIF.

        WHEN 'NODECLASS'.
          IF ls_sort-descending = abap_true.
            SORT ct_data BY nodeclass DESCENDING.
          ELSE.
            SORT ct_data BY nodeclass ASCENDING.
          ENDIF.

        WHEN 'NODEOBJECTTYPE'.
          IF ls_sort-descending = abap_true.
            SORT ct_data BY nodeobjecttype DESCENDING.
          ELSE.
            SORT ct_data BY nodeobjecttype ASCENDING.
          ENDIF.

        WHEN 'PARENTTEXT'.
          IF ls_sort-descending = abap_true.
            SORT ct_data BY parenttext DESCENDING.
          ELSE.
            SORT ct_data BY parenttext ASCENDING.
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_where_clause.
    DATA: lt_name_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    CLEAR rv_where.

    IF io_filter IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        lt_name_ranges = io_filter->get_as_ranges( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    LOOP AT lt_name_ranges INTO DATA(ls_name_range).
      DATA(lv_name) = to_upper( ls_name_range-name ).

      IF lv_name = 'PARENTNODEID'
         OR lv_name = 'MAXDEPTH'
         OR lv_name = 'P_MAX_DEPTH'
         OR lv_name CP '_CHARACTERISTICS*'.
        CONTINUE.
      ENDIF.

      DATA(lv_field_clause) = ``.
      DATA(lv_first) = abap_true.

      LOOP AT ls_name_range-range INTO DATA(ls_range).
        DATA(lv_cond) = ``.

        CASE ls_range-option.
          WHEN 'EQ'.
            lv_cond = |{ ls_name_range-name } = '{ ls_range-low }'|.
          WHEN 'NE'.
            lv_cond = |{ ls_name_range-name } <> '{ ls_range-low }'|.
          WHEN 'GE'.
            lv_cond = |{ ls_name_range-name } >= '{ ls_range-low }'|.
          WHEN 'LE'.
            lv_cond = |{ ls_name_range-name } <= '{ ls_range-low }'|.
          WHEN 'GT'.
            lv_cond = |{ ls_name_range-name } > '{ ls_range-low }'|.
          WHEN 'LT'.
            lv_cond = |{ ls_name_range-name } < '{ ls_range-low }'|.
          WHEN 'BT'.
            lv_cond = |{ ls_name_range-name } BETWEEN '{ ls_range-low }' AND '{ ls_range-high }'|.
          WHEN 'CP'.
            DATA(lv_pattern) = ls_range-low.
            REPLACE ALL OCCURRENCES OF '*' IN lv_pattern WITH '%'.
            lv_cond = |{ ls_name_range-name } LIKE '{ lv_pattern }'|.
          WHEN OTHERS.
            CONTINUE.
        ENDCASE.

        IF ls_range-sign = 'E'.
          lv_cond = |NOT ( { lv_cond } )|.
        ENDIF.

        IF lv_first = abap_true.
          lv_field_clause = |( { lv_cond } )|.
          lv_first = abap_false.
        ELSE.
          lv_field_clause = |{ lv_field_clause } OR ( { lv_cond } )|.
        ENDIF.
      ENDLOOP.

      IF lv_field_clause IS NOT INITIAL.
        IF rv_where IS INITIAL.
          rv_where = lv_field_clause.
        ELSE.
          rv_where = |{ rv_where } AND { lv_field_clause }|.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF iv_search_expression IS NOT INITIAL.
      DATA(lv_search) = iv_search_expression.

      REPLACE ALL OCCURRENCES OF '"' IN lv_search WITH ''.
      REPLACE ALL OCCURRENCES OF '''' IN lv_search WITH ''''''.
      REPLACE ALL OCCURRENCES OF '*' IN lv_search WITH '%'.
      TRANSLATE lv_search TO UPPER CASE.

      DATA(lv_search_clause) = |( UPPER( NODETEXT ) LIKE '%{ lv_search }%' )|.

      IF rv_where IS INITIAL.
        rv_where = lv_search_clause.
      ELSE.
        rv_where = |{ rv_where } AND { lv_search_clause }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD apply_characteristic_filters.
    DATA lt_name_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    IF io_filter IS NOT BOUND OR ct_data IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        lt_name_ranges = io_filter->get_as_ranges( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA lr_classification TYPE REF TO data.
    CREATE DATA lr_classification TYPE /bitmym/i_classification.
    DATA(lo_class_descr) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_data_ref( lr_classification ) ).
    DATA(lt_class_components) = lo_class_descr->get_components( ).
    FIELD-SYMBOLS <ls_component> LIKE LINE OF lt_class_components.

    LOOP AT lt_name_ranges INTO DATA(ls_name_range).
      DATA(lv_name_upper) = to_upper( ls_name_range-name ).
      IF lv_name_upper NP '_CHARACTERISTICS*' OR ls_name_range-range IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_char_field) = lv_name_upper.
      REPLACE FIRST OCCURRENCE OF '_CHARACTERISTICS/' IN lv_char_field WITH ''.
      REPLACE FIRST OCCURRENCE OF '_CHARACTERISTICS.' IN lv_char_field WITH ''.
      SHIFT lv_char_field LEFT DELETING LEADING '/'.
      SHIFT lv_char_field LEFT DELETING LEADING '.'.
      IF lv_char_field IS INITIAL.
        CONTINUE.
      ENDIF.

      READ TABLE lt_class_components ASSIGNING <ls_component>
        WITH KEY name = lv_char_field.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA lt_node_range TYPE RANGE OF /bitmym/i_classification-clfnobjectid.
      LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_data_node>).
        APPEND VALUE #(
          sign   = 'I'
          option = 'EQ'
          low    = CONV /bitmym/i_classification-clfnobjectid( <ls_data_node>-nodeid ) )
          TO lt_node_range.
      ENDLOOP.
      IF lt_node_range IS INITIAL.
        CLEAR ct_data.
        RETURN.
      ENDIF.

      DATA(lv_field_clause) = ``.
      DATA(lv_first) = abap_true.
      LOOP AT ls_name_range-range INTO DATA(ls_range).
        DATA(lv_low) = CONV string( ls_range-low ).
        DATA(lv_high) = CONV string( ls_range-high ).
        REPLACE ALL OCCURRENCES OF '''' IN lv_low WITH ''''''.
        REPLACE ALL OCCURRENCES OF '''' IN lv_high WITH ''''''.
        DATA(lv_cond) = ``.

        CASE ls_range-option.
          WHEN 'EQ'.
            lv_cond = |{ lv_char_field } = '{ lv_low }'|.
          WHEN 'NE'.
            lv_cond = |{ lv_char_field } <> '{ lv_low }'|.
          WHEN 'GE'.
            lv_cond = |{ lv_char_field } >= '{ lv_low }'|.
          WHEN 'LE'.
            lv_cond = |{ lv_char_field } <= '{ lv_low }'|.
          WHEN 'GT'.
            lv_cond = |{ lv_char_field } > '{ lv_low }'|.
          WHEN 'LT'.
            lv_cond = |{ lv_char_field } < '{ lv_low }'|.
          WHEN 'BT'.
            lv_cond = |{ lv_char_field } BETWEEN '{ lv_low }' AND '{ lv_high }'|.
          WHEN 'CP'.
            DATA(lv_pattern) = lv_low.
            REPLACE ALL OCCURRENCES OF '*' IN lv_pattern WITH '%'.
            lv_cond = |{ lv_char_field } LIKE '{ lv_pattern }'|.
          WHEN OTHERS.
            CONTINUE.
        ENDCASE.

        IF ls_range-sign = 'E'.
          lv_cond = |NOT ( { lv_cond } )|.
        ENDIF.

        IF lv_first = abap_true.
          lv_field_clause = |( { lv_cond } )|.
          lv_first = abap_false.
        ELSE.
          lv_field_clause = |{ lv_field_clause } OR ( { lv_cond } )|.
        ENDIF.
      ENDLOOP.

      IF lv_field_clause IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA lt_matching_nodes TYPE SORTED TABLE OF /bitmym/i_classification-clfnobjectid WITH UNIQUE KEY table_line.
      SELECT DISTINCT ClfnObjectID
        FROM /BITMYM/I_Classification
        WHERE ClfnObjectID IN @lt_node_range
          AND (lv_field_clause)
        INTO TABLE @lt_matching_nodes.

      IF lt_matching_nodes IS INITIAL.
        CLEAR ct_data.
        RETURN.
      ENDIF.

      DATA lt_matching_range TYPE RANGE OF /bitmym/i_product_catalog_hry-nodeid.
      LOOP AT lt_matching_nodes INTO DATA(lv_match_nodeid).
        APPEND VALUE #(
          sign = 'I'
          option = 'EQ'
          low = CONV /bitmym/i_product_catalog_hry-nodeid( lv_match_nodeid ) ) TO lt_matching_range.
      ENDLOOP.

      DELETE ct_data WHERE nodeid NOT IN lt_matching_range.
      IF ct_data IS INITIAL.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_orderby_clause.
    CLEAR rv_orderby.

    LOOP AT it_sort INTO DATA(ls_sort).
      DATA(lv_part) = ``.

      CASE to_upper( ls_sort-element_name ).
        WHEN 'NODEID'.
          lv_part = 'NODEID'.
        WHEN 'PARENTNODEID'.
          lv_part = 'PARENTNODEID'.
        WHEN 'NODETEXT'.
          lv_part = 'NODETEXT'.
        WHEN 'NODECLASS'.
          lv_part = 'NODECLASS'.
        WHEN 'NODEOBJECTTYPE'.
          lv_part = 'NODEOBJECTTYPE'.
        WHEN 'PARENTTEXT'.
          lv_part = 'PARENTTEXT'.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.

      IF ls_sort-descending = abap_true.
        lv_part = |{ lv_part } DESCENDING|.
      ELSE.
        lv_part = |{ lv_part } ASCENDING|.
      ENDIF.

      IF rv_orderby IS INITIAL.
        rv_orderby = lv_part.
      ELSE.
        rv_orderby = |{ rv_orderby }, { lv_part }|.
      ENDIF.
    ENDLOOP.

    IF rv_orderby IS INITIAL.
      rv_orderby = 'NODEID ASCENDING'.
    ENDIF.
  ENDMETHOD.


  METHOD get_select_list_from_request.
    DATA: lt_requested TYPE STANDARD TABLE OF string,
          lt_fields    TYPE STANDARD TABLE OF string WITH EMPTY KEY,
          lv_field     TYPE string.

    DATA: lo_struct TYPE REF TO cl_abap_structdescr,
          lt_comp   TYPE cl_abap_structdescr=>component_table.
    DATA: lr_data   TYPE REF TO data.

    FIELD-SYMBOLS: <ls_comp> LIKE LINE OF lt_comp.

    TRY.
        lt_requested = io_request->get_requested_elements( ).
      CATCH cx_root.
        CLEAR lt_requested.
    ENDTRY.

    CREATE DATA lr_data TYPE (gv_source_cds).

    lo_struct ?= cl_abap_typedescr=>describe_by_data_ref( lr_data ).
    lt_comp = lo_struct->get_components( ).

    LOOP AT lt_requested INTO DATA(lv_element).
      DATA(lv_name) = to_upper( lv_element ).

      IF lv_name CP '_*'.
        CONTINUE.
      ENDIF.

      READ TABLE lt_comp ASSIGNING <ls_comp>
        WITH KEY name = lv_name.
      IF sy-subrc = 0.
        IF <ls_comp>-type->kind = cl_abap_typedescr=>kind_table.
          CONTINUE.
        ENDIF.
        APPEND lv_name TO lt_fields.
      ENDIF.
    ENDLOOP.

    IF NOT line_exists( lt_fields[ table_line = 'NODEID' ] ).
      APPEND 'NODEID' TO lt_fields.
    ENDIF.

    IF NOT line_exists( lt_fields[ table_line = 'PARENTNODEID' ] ).
      APPEND 'PARENTNODEID' TO lt_fields.
    ENDIF.

    SORT lt_fields.
    DELETE ADJACENT DUPLICATES FROM lt_fields.

    LOOP AT lt_fields INTO lv_field.
      rv_select_list = COND string(
        WHEN rv_select_list IS INITIAL
        THEN lv_field
        ELSE |{ rv_select_list }, { lv_field }| ).
    ENDLOOP.

    IF rv_select_list IS INITIAL.
      rv_select_list = 'NODEID, PARENTNODEID'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
