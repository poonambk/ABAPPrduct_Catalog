CLASS /BITMYM/CL_PRODUCT_CATALOG_QP DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    CONSTANTS:
      gc_entity_product_catalog TYPE string VALUE '/BITMYM/C_PRODUCT_CATALOG',
      gc_entity_charc_basiclist TYPE string VALUE '/BITMYM/C_CHARCBASICLIST',
      gc_source_product_hry     TYPE string VALUE '/BITMYM/I_PRODUCT_CATALOG_HRY',
      gc_source_class_charac    TYPE string VALUE '/BITMYM/I_CLASS_CHARAC',
      gc_filter_parentnodeid    TYPE string VALUE 'PARENTNODEID',
      gc_filter_maxdepth_upper  TYPE string VALUE 'MAXDEPTH',
      gc_filter_maxdepth_mixed  TYPE string VALUE 'MaxDepth',
      gc_filter_p_max_depth     TYPE string VALUE 'P_MAX_DEPTH',
      gc_filter_maxdepth_lower  TYPE string VALUE 'maxdepth',
      gc_assoc_characteristics  TYPE string VALUE '_CHARACTERISTICS',
      gc_assoc_child            TYPE string VALUE '_CHILD'.

    TYPES:
      BEGIN OF ty_product_catalog,
        nodeid             TYPE /bitmym/i_product_catalog_hry-nodeid,
        parentnodeid       TYPE /bitmym/i_product_catalog_hry-parentnodeid,
        nodetext           TYPE /bitmym/i_product_catalog_hry-nodetext,
        nodeclass          TYPE /bitmym/i_product_catalog_hry-nodeclass,
        nodeobjecttype     TYPE /bitmym/i_product_catalog_hry-nodeobjecttype,
        maxdepth           TYPE /bitmym/i_product_catalog_adv-maxdepth,
        parenttext         TYPE /bitmym/i_product_catalog_hry-parenttext,
        hierarchylevel     TYPE /bitmym/i_product_cat_hry_adv-hierarchylevel,
        hierarchyparentrank TYPE /bitmym/i_product_cat_hry_adv-hierarchyparentrank,
        hierarchytreesize  TYPE /bitmym/i_product_cat_hry_adv-hierarchytreesize,
        drillstate         TYPE /bitmym/c_product_catalog_adv-drillstate,
        statusflag         TYPE /bitmym/i_product_catalog_adv-statusflag,
        _characteristics   TYPE STANDARD TABLE OF /bitmym/i_classification WITH EMPTY KEY,
        _child             TYPE STANDARD TABLE OF /bitmym/i_product_catalog_hry WITH EMPTY KEY,
      END OF ty_product_catalog,
      tty_product_catalog TYPE STANDARD TABLE OF ty_product_catalog WITH EMPTY KEY,
      tty_nodeid_range    TYPE RANGE OF /bitmym/i_product_catalog_hry-nodeid.

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
        it_sort            TYPE if_rap_query_request=>tt_sort_elements
      RETURNING
        VALUE(rv_orderby)  TYPE string.

    METHODS get_where_clause
      IMPORTING
        io_filter            TYPE REF TO if_rap_query_filter
        iv_search_expression TYPE string
      RETURNING
        VALUE(rv_where)      TYPE string.

    METHODS get_select_list_from_request
      IMPORTING
        io_request            TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rv_select_list) TYPE string.

    METHODS get_characteristic_node_range
      IMPORTING
        io_filter             TYPE REF TO if_rap_query_filter
      EXPORTING
        ev_filter_applied     TYPE abap_bool
      RETURNING
        VALUE(rt_nodeid_range) TYPE tty_nodeid_range.

    METHODS has_characteristic_filter
      IMPORTING
        io_filter                 TYPE REF TO if_rap_query_filter
      RETURNING
        VALUE(rv_has_char_filter) TYPE abap_bool.

    METHODS get_source_cds_for_entity
      IMPORTING
        iv_entity_id        TYPE string
      RETURNING
        VALUE(rv_source_cds) TYPE string.

    METHODS get_filter_ranges
      IMPORTING
        io_filter             TYPE REF TO if_rap_query_filter
      RETURNING
        VALUE(rt_name_ranges) TYPE if_rap_query_filter=>tt_name_range_pairs.

    METHODS determine_requested_expands
      IMPORTING
        io_request      TYPE REF TO if_rap_query_request
      EXPORTING
        ev_expand_char  TYPE abap_bool
        ev_expand_child TYPE abap_bool.

    METHODS get_fetch_rows
      IMPORTING
        iv_has_paging TYPE abap_bool
        iv_offset     TYPE i
        iv_page_size  TYPE i
      RETURNING
        VALUE(rv_fetch_rows) TYPE i.

    METHODS read_root_data
      IMPORTING
        iv_select_list      TYPE string
        iv_from_syntax      TYPE string
        iv_where            TYPE string
        iv_orderby          TYPE string
        iv_fetch_rows       TYPE i
        iv_apply_node_filter TYPE abap_bool
        it_nodeid_range     TYPE tty_nodeid_range
      CHANGING
        ct_data             TYPE tty_product_catalog.

    METHODS expand_characteristics
      CHANGING
        ct_data TYPE tty_product_catalog.

    METHODS expand_child_nodes
      CHANGING
        ct_data TYPE tty_product_catalog.

    METHODS get_total_count
      IMPORTING
        iv_from_syntax      TYPE string
        iv_where            TYPE string
        iv_apply_node_filter TYPE abap_bool
        it_nodeid_range     TYPE tty_nodeid_range
      RETURNING
        VALUE(rv_count)     TYPE int8.

    METHODS apply_requested_paging
      IMPORTING
        iv_has_paging TYPE abap_bool
        iv_offset     TYPE i
        iv_page_size  TYPE i
      CHANGING
        ct_data       TYPE tty_product_catalog.

ENDCLASS.



CLASS /BITMYM/CL_PRODUCT_CATALOG_QP IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA:
      lt_data               TYPE tty_product_catalog,
      lv_root_node          TYPE /bitmym/i_product_catalog_hry-nodeid,
      lv_max_depth          TYPE i,
      lv_count              TYPE int8,
      lv_data_requested     TYPE abap_bool,
      lv_count_requested    TYPE abap_bool,
      lv_page_size          TYPE i,
      lv_offset             TYPE i,
      lv_where              TYPE string,
      lv_orderby            TYPE string,
      lv_expand_char        TYPE abap_bool,
      lv_expand_child       TYPE abap_bool,
      lv_has_char_filter    TYPE abap_bool,
      lv_char_filter_applied TYPE abap_bool,
      lv_has_paging         TYPE abap_bool,
      lv_fetch_rows         TYPE i.

    lv_data_requested = io_request->is_data_requested( ).
    lv_count_requested = io_request->is_total_numb_of_rec_requested( ).
    IF lv_data_requested = abap_false
       AND lv_count_requested = abap_false.
      RETURN.
    ENDIF.

    gv_source_cds = get_source_cds_for_entity( io_request->get_entity_id( ) ).

    DATA(lo_filter) = io_request->get_filter( ).
    lv_root_node = get_root_node( lo_filter ).
    lv_max_depth = get_max_depth_from_filter( lo_filter ).

    DATA(lo_paging) = io_request->get_paging( ).
    lv_has_paging = xsdbool( lo_paging IS BOUND ).
    IF lv_has_paging = abap_true.
      lv_offset = lo_paging->get_offset( ).
      lv_page_size = lo_paging->get_page_size( ).
    ENDIF.

    lv_where = get_where_clause(
      io_filter            = lo_filter
      iv_search_expression = io_request->get_search_expression( ) ).
    lv_orderby = get_orderby_clause( io_request->get_sort_elements( ) ).

    lv_has_char_filter = has_characteristic_filter( lo_filter ).
    DATA(lt_char_nodeids) = get_characteristic_node_range(
      EXPORTING
        io_filter         = lo_filter
      IMPORTING
        ev_filter_applied = lv_char_filter_applied ).

    IF lv_has_char_filter = abap_true AND lv_char_filter_applied = abap_false.
      CLEAR lt_data.
    ELSE.
      determine_requested_expands(
        EXPORTING
          io_request      = io_request
        IMPORTING
          ev_expand_char  = lv_expand_char
          ev_expand_child = lv_expand_child ).

      lv_fetch_rows = get_fetch_rows(
        iv_has_paging = lv_has_paging
        iv_offset     = lv_offset
        iv_page_size  = lv_page_size ).

      DATA(lv_select_list) = get_select_list_from_request( io_request ).
      DATA(lv_from_syntax) = |{ gv_source_cds }( p_root_node = @lv_root_node, p_max_depth = @lv_max_depth )|.

      read_root_data(
        EXPORTING
          iv_select_list       = lv_select_list
          iv_from_syntax       = lv_from_syntax
          iv_where             = lv_where
          iv_orderby           = lv_orderby
          iv_fetch_rows        = lv_fetch_rows
          iv_apply_node_filter = lv_char_filter_applied
          it_nodeid_range      = lt_char_nodeids
        CHANGING
          ct_data              = lt_data ).

      IF lv_expand_char = abap_true.
        expand_characteristics( CHANGING ct_data = lt_data ).
      ENDIF.

      IF lv_expand_child = abap_true.
        expand_child_nodes( CHANGING ct_data = lt_data ).
      ENDIF.

      IF lv_count_requested = abap_true.
        lv_count = get_total_count(
          iv_from_syntax       = lv_from_syntax
          iv_where             = lv_where
          iv_apply_node_filter = lv_char_filter_applied
          it_nodeid_range      = lt_char_nodeids ).
        io_response->set_total_number_of_records( lv_count ).
      ENDIF.
    ENDIF.

    IF lv_data_requested = abap_true.
      apply_requested_paging(
        EXPORTING
          iv_has_paging = lv_has_paging
          iv_offset     = lv_offset
          iv_page_size  = lv_page_size
        CHANGING
          ct_data       = lt_data ).
      io_response->set_data( lt_data ).
    ENDIF.
  ENDMETHOD.


  METHOD get_filter_ranges.
    CLEAR rt_name_ranges.
    IF io_filter IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        rt_name_ranges = io_filter->get_as_ranges( ).
      CATCH cx_root.
        CLEAR rt_name_ranges.
    ENDTRY.
  ENDMETHOD.


  METHOD determine_requested_expands.
    ev_expand_char = abap_false.
    ev_expand_child = abap_false.

    DATA(lt_expand) = io_request->get_requested_elements( ).
    LOOP AT lt_expand INTO DATA(lv_expand).
      CASE lv_expand.
        WHEN gc_assoc_characteristics.
          ev_expand_char = abap_true.
        WHEN gc_assoc_child.
          ev_expand_child = abap_true.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_fetch_rows.
    rv_fetch_rows = 0.
    IF iv_has_paging = abap_true
       AND iv_page_size <> if_rap_query_paging=>page_size_unlimited.
      rv_fetch_rows = iv_offset + iv_page_size.
    ENDIF.
  ENDMETHOD.


  METHOD read_root_data.
    CLEAR ct_data.

    IF iv_apply_node_filter = abap_true AND it_nodeid_range IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_has_row_limit) = xsdbool( iv_fetch_rows > 0 ).

    IF iv_where IS INITIAL.
      IF lv_has_row_limit = abap_true.
        SELECT (iv_select_list)
          FROM (iv_from_syntax)
          WHERE ( @iv_apply_node_filter = @abap_false
                  OR nodeid IN @it_nodeid_range )
          ORDER BY (iv_orderby)
          INTO CORRESPONDING FIELDS OF TABLE @ct_data
          UP TO @iv_fetch_rows ROWS.
      ELSE.
        SELECT (iv_select_list)
          FROM (iv_from_syntax)
          WHERE ( @iv_apply_node_filter = @abap_false
                  OR nodeid IN @it_nodeid_range )
          ORDER BY (iv_orderby)
          INTO CORRESPONDING FIELDS OF TABLE @ct_data.
      ENDIF.
    ELSE.
      IF lv_has_row_limit = abap_true.
        SELECT DISTINCT (iv_select_list)
          FROM (iv_from_syntax)
          WHERE (iv_where)
            AND ( @iv_apply_node_filter = @abap_false
                  OR nodeid IN @it_nodeid_range )
          ORDER BY (iv_orderby)
          INTO CORRESPONDING FIELDS OF TABLE @ct_data
          UP TO @iv_fetch_rows ROWS.
      ELSE.
        SELECT DISTINCT (iv_select_list)
          FROM (iv_from_syntax)
          WHERE (iv_where)
            AND ( @iv_apply_node_filter = @abap_false
                  OR nodeid IN @it_nodeid_range )
          ORDER BY (iv_orderby)
          INTO CORRESPONDING FIELDS OF TABLE @ct_data.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD expand_characteristics.
    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    SELECT a~nodeid,
           b~*
      FROM @ct_data AS a
      INNER JOIN /BITMYM/I_Classification AS b
        ON b~ClfnObjectID = a~nodeid
      INTO TABLE @DATA(lt_joined_char).

    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      <ls_data>-_characteristics =
        VALUE #(
          FOR ls_join IN lt_joined_char
          WHERE ( nodeid = <ls_data>-nodeid )
          ( CORRESPONDING #( ls_join ) )
        ).
    ENDLOOP.
  ENDMETHOD.


  METHOD expand_child_nodes.
    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    SELECT
      _child~NodeID,
      _child~ParentNodeID,
      _child~ClassType,
      _child~NodeText,
      _child~NodeClass,
      _child~ParentText,
      _child~NodeObjectType
      FROM @ct_data AS _parent
      INNER JOIN /BITMYM/I_PRODUCT_CLASS AS _child
        ON _child~parentnodeid = _parent~nodeid
      INTO TABLE @DATA(lt_child_joined).

    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_data>).
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
  ENDMETHOD.


  METHOD get_total_count.
    IF iv_apply_node_filter = abap_true AND it_nodeid_range IS INITIAL.
      rv_count = 0.
      RETURN.
    ENDIF.

    IF iv_where IS INITIAL.
      IF iv_apply_node_filter = abap_true.
        SELECT COUNT( * )
          FROM (iv_from_syntax)
          WHERE nodeid IN @it_nodeid_range
          INTO @rv_count.
      ELSE.
        SELECT COUNT( * )
          FROM (iv_from_syntax)
          INTO @rv_count.
      ENDIF.
    ELSE.
      IF iv_apply_node_filter = abap_true.
        SELECT COUNT( * )
          FROM (iv_from_syntax)
          WHERE (iv_where)
            AND nodeid IN @it_nodeid_range
          INTO @rv_count.
      ELSE.
        SELECT COUNT( * )
          FROM (iv_from_syntax)
          WHERE (iv_where)
          INTO @rv_count.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD apply_requested_paging.
    IF iv_has_paging = abap_false.
      RETURN.
    ENDIF.

    IF iv_page_size = if_rap_query_paging=>page_size_unlimited.
      IF iv_offset > 0.
        apply_paging(
          EXPORTING
            iv_offset = iv_offset
            iv_top    = 0
          CHANGING
            ct_data   = ct_data ).
      ENDIF.
    ELSE.
      apply_paging(
        EXPORTING
          iv_offset = iv_offset
          iv_top    = iv_page_size
        CHANGING
          ct_data   = ct_data ).
    ENDIF.
  ENDMETHOD.


  METHOD has_characteristic_filter.
    rv_has_char_filter = abap_false.

    DATA(lt_name_ranges) = get_filter_ranges( io_filter ).
    LOOP AT lt_name_ranges INTO DATA(ls_name_range).
      IF to_upper( ls_name_range-name ) CP |{ gc_assoc_characteristics }*|.
        rv_has_char_filter = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_characteristic_node_range.
    CLEAR rt_nodeid_range.
    ev_filter_applied = abap_false.

    IF io_filter IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(lt_name_ranges) = get_filter_ranges( io_filter ).
    IF lt_name_ranges IS INITIAL.
      RETURN.
    ENDIF.

    DATA lr_classification TYPE REF TO data.
    CREATE DATA lr_classification TYPE /bitmym/i_classification.
    DATA(lo_class_descr) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_data_ref( lr_classification ) ).
    DATA(lt_class_components) = lo_class_descr->get_components( ).
    FIELD-SYMBOLS <ls_component> LIKE LINE OF lt_class_components.

    DATA lt_matching_all TYPE SORTED TABLE OF /bitmym/i_classification-clfnobjectid WITH UNIQUE KEY table_line.
    DATA lv_initialized TYPE abap_bool VALUE abap_false.

    LOOP AT lt_name_ranges INTO DATA(ls_name_range).
      DATA(lv_name_upper) = to_upper( ls_name_range-name ).
      IF lv_name_upper NP |{ gc_assoc_characteristics }*|
         OR ls_name_range-range IS INITIAL.
        CONTINUE.
      ENDIF.

      ev_filter_applied = abap_true.

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

      DATA lt_matching_current TYPE SORTED TABLE OF /bitmym/i_classification-clfnobjectid WITH UNIQUE KEY table_line.
      IF lv_initialized = abap_false.
        SELECT DISTINCT ClfnObjectID
          FROM /BITMYM/I_Classification
          WHERE (lv_field_clause)
          INTO TABLE @lt_matching_current.

        lt_matching_all = lt_matching_current.
        lv_initialized = abap_true.
      ELSE.
        SELECT DISTINCT c~ClfnObjectID
          FROM /BITMYM/I_Classification AS c
          INNER JOIN @lt_matching_all AS m
            ON m~table_line = c~ClfnObjectID
          WHERE (lv_field_clause)
          INTO TABLE @lt_matching_current.

        lt_matching_all = lt_matching_current.
      ENDIF.

      IF lt_matching_all IS INITIAL.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF ev_filter_applied = abap_false.
      RETURN.
    ENDIF.

    LOOP AT lt_matching_all INTO DATA(lv_match_nodeid).
      APPEND VALUE #(
        sign   = 'I'
        option = 'EQ'
        low    = CONV /bitmym/i_product_catalog_hry-nodeid( lv_match_nodeid ) )
        TO rt_nodeid_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_source_cds_for_entity.
    CASE iv_entity_id.
      WHEN gc_entity_product_catalog.
        rv_source_cds = gc_source_product_hry.
      WHEN gc_entity_charc_basiclist.
        rv_source_cds = gc_source_class_charac.
      WHEN OTHERS.
        rv_source_cds = gc_source_product_hry.
    ENDCASE.
  ENDMETHOD.


  METHOD get_root_node.
    DATA: ld_class_type TYPE klah-klart,
          ld_class_num  TYPE klah-class,
          ls_area       TYPE /sopromet/zzl01.

    CLEAR rv_root_node.

    DATA(lt_name_ranges) = get_filter_ranges( io_filter ).
    READ TABLE lt_name_ranges INTO DATA(ls_name_range)
      WITH KEY name = gc_filter_parentnodeid.
    IF sy-subrc = 0 AND ls_name_range-range IS NOT INITIAL.
      READ TABLE ls_name_range-range INTO DATA(ls_range) INDEX 1.
      IF sy-subrc = 0 AND ls_range-low IS NOT INITIAL.
        rv_root_node = CONV /bitmym/i_product_catalog_hry-parentnodeid( ls_range-low ).
        RETURN.
      ENDIF.
    ENDIF.

    IF gv_source_cds = gc_source_product_hry.
      RETURN.
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
  ENDMETHOD.


  METHOD get_max_depth_from_filter.
    rv_max_depth = 99.

    DATA(lt_name_ranges) = get_filter_ranges( io_filter ).
    IF lt_name_ranges IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE lt_name_ranges INTO DATA(ls_name_range)
      WITH KEY name = gc_filter_maxdepth_upper.
    IF sy-subrc <> 0.
      READ TABLE lt_name_ranges INTO ls_name_range
        WITH KEY name = gc_filter_maxdepth_mixed.
    ENDIF.
    IF sy-subrc <> 0.
      READ TABLE lt_name_ranges INTO ls_name_range
        WITH KEY name = gc_filter_p_max_depth.
    ENDIF.
    IF sy-subrc <> 0.
      READ TABLE lt_name_ranges INTO ls_name_range
        WITH KEY name = gc_filter_maxdepth_lower.
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


  METHOD get_where_clause.
    CLEAR rv_where.

    DATA(lt_name_ranges) = get_filter_ranges( io_filter ).
    LOOP AT lt_name_ranges INTO DATA(ls_name_range).
      DATA(lv_name) = to_upper( ls_name_range-name ).

      IF lv_name = gc_filter_parentnodeid
         OR lv_name = gc_filter_maxdepth_upper
         OR lv_name = to_upper( gc_filter_maxdepth_mixed )
         OR lv_name = gc_filter_p_max_depth
         OR lv_name = to_upper( gc_filter_maxdepth_lower )
         OR lv_name CP |{ gc_assoc_characteristics }*|.
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

      DATA(lv_search_clause) =
        |( UPPER( NODETEXT ) LIKE '%{ lv_search }%' |
        && |OR NODEID IN ( |
        && |SELECT DISTINCT ClfnObjectID |
        && |FROM /BITMYM/I_Classification |
        && |WHERE UPPER( CHARVALUE ) LIKE '%{ lv_search }%' ) )|.
      IF rv_where IS INITIAL.
        rv_where = lv_search_clause.
      ELSE.
        rv_where = |{ rv_where } AND { lv_search_clause }|.
      ENDIF.
    ENDIF.
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
    DATA lr_data TYPE REF TO data.

    FIELD-SYMBOLS <ls_comp> LIKE LINE OF lt_comp.

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
