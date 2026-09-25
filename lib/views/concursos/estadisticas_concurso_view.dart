import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/concurso.dart';
import '../../models/concurso_estadisticas.dart';
import '../../providers/estadisticas_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../common/excel_export_dropdown.dart';

class EstadisticasConcursoView extends ConsumerWidget {
  final Concurso concurso;

  const EstadisticasConcursoView({
    super.key,
    required this.concurso,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(concursoEstadisticasProvider(concurso.id!));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Estadísticas del Concurso',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.casart800,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Regresar a Concursos',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar Estadísticas',
            onPressed: () {
              ref.invalidate(concursoEstadisticasProvider(concurso.id!));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Calculando estadísticas del concurso...',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  'Error al cargar estadísticas: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 15),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  onPressed: () => ref.invalidate(concursoEstadisticasProvider(concurso.id!)),
                ),
              ],
            ),
          ),
        ),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Breadcrumbs
              _buildBreadcrumbs(context, stats.concurso, isDark),

              const SizedBox(height: 16),

              // 2. Banner de encabezado del concurso
              _buildHeaderBanner(context, stats, isDark),

              const SizedBox(height: 24),

              // 3. Tarjetas KPI Métricas
              _buildKpiGrid(context, stats, isDark),

              const SizedBox(height: 24),

              // 4. Secciones de Desglose
              _buildBreakdownSections(context, stats, isDark),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. BREADCRUMBS
  // ===========================================================================
  Widget _buildBreadcrumbs(BuildContext context, Concurso c, bool isDark) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 16,
                  color: isDark ? Colors.blue.shade300 : AppTheme.azulAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  'Concursos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.blue.shade300 : AppTheme.azulAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
        ),
        Flexible(
          child: Text(
            c.nombre,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.purple.shade900.withValues(alpha: 0.3) : AppTheme.casart50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Estadísticas',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.casart800,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. BANNER DE ENCABEZADO
  // ===========================================================================
  Widget _buildHeaderBanner(BuildContext context, ConcursoEstadisticas stats, bool isDark) {
    final c = stats.concurso;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          final infoColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics_outlined, size: 14, color: Color(0xFFB45309)),
                        SizedBox(width: 4),
                        Text(
                          'Estadísticas Generales',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.finalizado)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'FINALIZADO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.verdeLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.verdeBorder),
                      ),
                      child: const Text(
                        'EN PROCESO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.verdeSuccess,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                c.nombre,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (c.ejercicio.isNotEmpty)
                    Text(
                      'Ejercicio Fiscal: ${c.ejercicio}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (c.lugar != null && c.lugar!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          c.lugar!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          );

          final actionsRow = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Exportador Excel oficial con Formatos A, B, C y D
              ExcelExportDropdown(
                concurso: c,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoColumn,
                const SizedBox(height: 16),
                actionsRow,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: infoColumn),
              const SizedBox(width: 16),
              actionsRow,
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 3. TARJETAS KPI MÉTRICAS (GRID DE 6 TARJETAS)
  // ===========================================================================
  Widget _buildKpiGrid(BuildContext context, ConcursoEstadisticas stats, bool isDark) {
    final kpis = [
      _KpiData(
        title: 'Artesanos Participantes',
        value: '${stats.totalArtesanos}',
        subtitle: 'Registrados en el concurso',
        icon: Icons.people_alt_outlined,
        iconBgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF16A34A),
      ),
      _KpiData(
        title: 'Municipios Participantes',
        value: '${stats.totalMunicipios}',
        valueSuffix: ' municipios',
        subtitle: 'Origen de los artesanos',
        icon: Icons.location_on_outlined,
        iconBgColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFF0FDFA),
        iconColor: const Color(0xFF0D9488),
      ),
      _KpiData(
        title: 'Piezas Inscritas',
        value: '${stats.totalPiezas}',
        subtitle: 'Obras participantes',
        icon: Icons.inventory_2_outlined,
        iconBgColor: isDark ? const Color(0xFF581C87) : const Color(0xFFFAF5FF),
        iconColor: const Color(0xFF9333EA),
      ),
      _KpiData(
        title: 'Categorías / Subcategorías',
        value: '${stats.totalCategorias} cat. / ${stats.totalSubcategorias} subcat.',
        subtitle: 'Definidas en el concurso',
        icon: Icons.category_outlined,
        iconBgColor: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
        iconColor: const Color(0xFF4F46E5),
      ),
      _KpiData(
        title: 'Premios Configurados',
        value: '${stats.totalPremios}',
        subtitle: 'Galardones, especiales y comunes',
        icon: Icons.military_tech_outlined,
        iconBgColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      ),
      _KpiData(
        title: 'Bolsa de Premiación',
        value: Formatters.formatCurrency(stats.bolsaPremios),
        subtitle: 'Monto total a repartir',
        icon: Icons.attach_money_outlined,
        iconBgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFD97706),
        valueColor: const Color(0xFFD97706),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 3;
        if (constraints.maxWidth < 650) {
          columns = 1;
        } else if (constraints.maxWidth < 1050) {
          columns = 2;
        }

        final double cardWidth = (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: kpis.map((kpi) {
            return SizedBox(
              width: cardWidth,
              child: _buildKpiCard(context, kpi, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(BuildContext context, _KpiData kpi, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kpi.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        kpi.value,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kpi.valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                    if (kpi.valueSuffix != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        kpi.valueSuffix!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  kpi.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kpi.iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(kpi.icon, size: 24, color: kpi.iconColor),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. SECCIONES DE DESGLOSE (ETNIA, GÉNERO, MUNICIPIOS, CATEGORÍAS)
  // ===========================================================================
  Widget _buildBreakdownSections(BuildContext context, ConcursoEstadisticas stats, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTwoCol = constraints.maxWidth >= 900;

        final cardEtnias = _buildEtniasCard(context, stats, isDark);
        final cardGeneroRamas = _buildGeneroRamasCard(context, stats, isDark);
        final cardMunicipios = _buildMunicipiosCard(context, stats, isDark);
        final cardCategorias = _buildCategoriasCard(context, stats, isDark);

        if (isTwoCol) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cardEtnias),
                  const SizedBox(width: 20),
                  Expanded(child: cardGeneroRamas),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cardMunicipios),
                  const SizedBox(width: 20),
                  Expanded(child: cardCategorias),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            cardEtnias,
            const SizedBox(height: 20),
            cardGeneroRamas,
            const SizedBox(height: 20),
            cardMunicipios,
            const SizedBox(height: 20),
            cardCategorias,
          ],
        );
      },
    );
  }

  // --- TARJETA: ARTESANOS POR PUEBLO INDÍGENA / ETNIA ---
  Widget _buildEtniasCard(BuildContext context, ConcursoEstadisticas stats, bool isDark) {
    final total = stats.totalArtesanos;
    final etnias = stats.etniasConteo;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Artesanos por Pueblo Indígena / Etnia',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${etnias.length} grupos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (etnias.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No hay artesanos registrados.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: etnias.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final entry = etnias.entries.elementAt(index);
                  final double pct = total > 0 ? (entry.value / total) * 100 : 0.0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade200 : const Color(0xFF334155),
                              ),
                            ),
                            Text(
                              '${entry.value} artesano${entry.value > 1 ? 's' : ''} (${pct.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100.0,
                            minHeight: 6,
                            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- TARJETA: DISTRIBUCIÓN POR GÉNERO & PIEZAS POR RAMA ARTESANAL ---
  Widget _buildGeneroRamasCard(BuildContext context, ConcursoEstadisticas stats, bool isDark) {
    final total = stats.totalArtesanos;
    final double pctHombres = total > 0 ? (stats.totalHombres / total) * 100 : 0.0;
    final double pctMujeres = total > 0 ? (stats.totalMujeres / total) * 100 : 0.0;
    final ramas = stats.ramasConteo;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución por Género',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),

          // Cajas de Género Hombres / Mujeres
          Row(
            children: [
              // Hombres
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E40AF).withValues(alpha: 0.5) : const Color(0xFFDBEAFE),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${stats.totalHombres}',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HOMBRES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${pctHombres.toStringAsFixed(1)}% del total',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Mujeres
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF831843).withValues(alpha: 0.25) : const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF9D174D).withValues(alpha: 0.5) : const Color(0xFFFCE7F3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${stats.totalMujeres}',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MUJERES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFFEC4899) : const Color(0xFFDB2777),
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${pctMujeres.toStringAsFixed(1)}% del total',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFF472B6) : const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Sub-sección: Piezas por Rama Artesanal
          Text(
            'Piezas por Rama Artesanal',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),

          if (ramas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No hay registros de ramas artesanales.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: ramas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final entry = ramas.entries.elementAt(index);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value} pieza${entry.value > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- TARJETA: MUNICIPIOS DE ORIGEN ---
  Widget _buildMunicipiosCard(BuildContext context, ConcursoEstadisticas stats, bool isDark) {
    final municipios = stats.municipiosConteo;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Municipios de Origen',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF134E4A).withValues(alpha: 0.4) : const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF115E59) : const Color(0xFFCCFBF1),
                  ),
                ),
                child: Text(
                  '${stats.totalMunicipios} municipios',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (municipios.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No hay municipios registrados.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: municipios.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = municipios.entries.elementAt(index);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade200 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF134E4A).withValues(alpha: 0.5) : const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value} artesano${entry.value > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- TARJETA: CATEGORÍAS Y SUBCATEGORÍAS ---
  Widget _buildCategoriasCard(BuildContext context, ConcursoEstadisticas stats, bool isDark) {
    final cats = stats.categoriasConcurso;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Categorías y Subcategorías',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE),
                  ),
                ),
                child: Text(
                  '${stats.totalCategorias} cat. | ${stats.totalSubcategorias} subcat.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (cats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No hay categorías configuradas para este concurso.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final cat = cats[index];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat.nombre,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey.shade200 : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (cat.subcategorias.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: cat.subcategorias.map((sub) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.subdirectory_arrow_right,
                                        size: 13,
                                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          sub.nombre,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(
                              'Sin subcategorías específicas.',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String? valueSuffix;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color? valueColor;

  const _KpiData({
    required this.title,
    required this.value,
    this.valueSuffix,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.valueColor,
  });
}
