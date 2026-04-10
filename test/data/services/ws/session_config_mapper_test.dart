import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/models/acp_session_models.dart';
import 'package:muxagent/data/services/ws/session_config_mapper.dart';

void main() {
  test('falls back to ACP modes when no mode config option is present', () {
    final snapshot = SessionConfigMapper.snapshotFromConfigOptions(
      runtimeId: 'claude-code',
      configOptions: const [
        AcpSessionConfigOptionDto(
          id: 'model',
          name: 'Model',
          type: 'select',
          currentValue: 'opus',
          options: AcpSessionConfigSelectOptionsDto(
            ungrouped: [
              AcpSessionConfigSelectOptionDto(value: 'opus', name: 'Opus'),
            ],
          ),
        ),
      ],
      modes: const AcpSessionModeStateDto(
        currentModeId: 'plan',
        availableModes: [
          AcpSessionModeDto(id: 'default', name: 'Default'),
          AcpSessionModeDto(id: 'plan', name: 'Plan'),
          AcpSessionModeDto(id: 'bypassPermissions', name: 'Skip Perms'),
        ],
      ),
    );

    expect(snapshot.currentMode?.id, 'plan');
    expect(
      snapshot.availableModes.map((mode) => mode.id),
      containsAllInOrder(['bypassPermissions', 'default', 'plan']),
    );
  });

  test('prefers mode config options over ACP modes when both are present', () {
    final snapshot = SessionConfigMapper.snapshotFromConfigOptions(
      runtimeId: 'codex',
      configOptions: const [
        AcpSessionConfigOptionDto(
          id: 'mode',
          name: 'Approval Preset',
          type: 'select',
          currentValue: 'auto',
          category: 'mode',
          options: AcpSessionConfigSelectOptionsDto(
            ungrouped: [
              AcpSessionConfigSelectOptionDto(
                value: 'read-only',
                name: 'Read Only',
              ),
              AcpSessionConfigSelectOptionDto(value: 'auto', name: 'Default'),
            ],
          ),
        ),
      ],
      modes: const AcpSessionModeStateDto(
        currentModeId: 'full-access',
        availableModes: [
          AcpSessionModeDto(id: 'full-access', name: 'Full Access'),
        ],
      ),
    );

    expect(snapshot.currentMode?.id, 'auto');
    expect(snapshot.availableModes.map((mode) => mode.id), [
      'auto',
      'read-only',
    ]);
  });

  test('orders OpenCode modes as build then plan from config options', () {
    final snapshot = SessionConfigMapper.snapshotFromConfigOptions(
      runtimeId: 'opencode',
      configOptions: const [
        AcpSessionConfigOptionDto(
          id: 'mode',
          name: 'Mode',
          type: 'select',
          currentValue: 'build',
          category: 'mode',
          options: AcpSessionConfigSelectOptionsDto(
            ungrouped: [
              AcpSessionConfigSelectOptionDto(value: 'plan', name: 'Plan'),
              AcpSessionConfigSelectOptionDto(value: 'build', name: 'Build'),
            ],
          ),
        ),
      ],
    );

    expect(snapshot.currentMode?.id, 'build');
    expect(snapshot.availableModes.map((mode) => mode.id), ['build', 'plan']);
  });
}
