library paginate_firestore;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/pagination_listeners.dart';
import 'bloc/pagination_bloc.dart';
import 'widgets/bottom_loader.dart';
import 'widgets/empty_display.dart';
import 'widgets/empty_separator.dart';
import 'widgets/error_display.dart';
import 'widgets/initial_loader.dart';

class PaginateFirestore extends StatefulWidget {
  const PaginateFirestore(
      {Key key,
      @required this.itemBuilder,
      @required this.query,
      @required this.itemBuilderType,
      this.gridDelegate =
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      this.startAfterDocument,
      this.itemsPerPage = 15,
      this.onError,
      this.emptyDisplay = const EmptyDisplay(),
      this.separator = const EmptySeparator(),
      this.initialLoader = const InitialLoader(),
      this.bottomLoader = const BottomLoader(),
      this.shrinkWrap = false,
      this.reverse = false,
      this.scrollDirection = Axis.vertical,
      this.padding = const EdgeInsets.all(0),
      this.physics,
      this.listeners})
      : super(key: key);

  final Widget bottomLoader;
  final Widget emptyDisplay;
  final SliverGridDelegate gridDelegate;
  final Widget initialLoader;
  final dynamic itemBuilderType;
  final int itemsPerPage;
  final EdgeInsets padding;
  final ScrollPhysics physics;
  final Query query;
  final bool reverse;
  final Axis scrollDirection;
  final Widget separator;
  final bool shrinkWrap;
  final DocumentSnapshot startAfterDocument;
  final List<ChangeNotifier> listeners;

  @override
  _PaginateFirestoreState createState() => _PaginateFirestoreState();

  final Widget Function(Exception) onError;

  final Widget Function(int, BuildContext, DocumentSnapshot) itemBuilder;
}

class _PaginateFirestoreState extends State<PaginateFirestore> {
  PaginationBloc _bloc;
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaginationBloc, PaginationState>(
      cubit: _bloc,
      builder: (context, state) {
        if (state is PaginationInitial) {
          return widget.initialLoader;
        } else if (state is PaginationError) {
          return (widget.onError != null)
              ? widget.onError(state.error)
              : ErrorDisplay(exception: state.error);
        } else {
          final loadedState = state as PaginationLoaded;
          if (loadedState.documentSnapshots.isEmpty) {
            return widget.emptyDisplay;
          }
          return widget.itemBuilderType == PaginateBuilderType.listView
              ? _buildListView(loadedState)
              : _buildGridView(loadedState);
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.listeners != null) {
      for (ChangeNotifier listener in widget.listeners) {
        if (listener is PaginateRefreshedChangeListener) {
          listener.addListener(() {
            if (listener.refreshed) {
              refresh();
            }
          });
        } else if (listener is PaginateSearchChangeListener) {
          listener.addListener(() {
            throw new UnimplementedError();
          });
        }
      }
    }

    _bloc = PaginationBloc(
      widget.query,
      widget.itemsPerPage,
      widget.startAfterDocument,
    )..add(PageFetch());
  }

  void refresh() {
    _bloc..add(PageRefreshed());
  }

  Widget _buildGridView(PaginationLoaded loadedState) {
    return MultiProvider(
      providers: widget.listeners
          .map((_listener) => ChangeNotifierProvider(
                create: (context) => _listener,
              ))
          .toList(),
      child: GridView.builder(
        controller: _scrollController,
        itemCount: loadedState.hasReachedEnd
            ? loadedState.documentSnapshots.length
            : loadedState.documentSnapshots.length + 1,
        gridDelegate: widget.gridDelegate,
        reverse: widget.reverse,
        shrinkWrap: widget.shrinkWrap,
        scrollDirection: widget.scrollDirection,
        physics: widget.physics,
        padding: widget.padding,
        itemBuilder: (context, index) {
          if (index >= loadedState.documentSnapshots.length) {
            _bloc.add(PageFetch());
            return widget.bottomLoader;
          }
          return widget.itemBuilder(
              index, context, loadedState.documentSnapshots[index]);
        },
      ),
    );
  }

  Widget _buildListView(PaginationLoaded loadedState) {
    return MultiProvider(
      providers: widget.listeners
          .map((_listener) => ChangeNotifierProvider(
                create: (context) => _listener,
              ))
          .toList(),
      child: ListView.separated(
        controller: _scrollController,
        reverse: widget.reverse,
        shrinkWrap: widget.shrinkWrap,
        scrollDirection: widget.scrollDirection,
        physics: widget.physics,
        padding: widget.padding,
        separatorBuilder: (context, index) => widget.separator,
        itemCount: loadedState.hasReachedEnd
            ? loadedState.documentSnapshots.length
            : loadedState.documentSnapshots.length + 1,
        itemBuilder: (context, index) {
          if (index >= loadedState.documentSnapshots.length) {
            _bloc.add(PageFetch());
            return widget.bottomLoader;
          }
          return widget.itemBuilder(
              index, context, loadedState.documentSnapshots[index]);
        },
      ),
    );
  }
}

enum PaginateBuilderType { listView, gridView }
